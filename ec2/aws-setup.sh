#!/usr/bin/env bash
# Manage the interview EC2 box. Identified by tag Name=$INSTANCE_NAME so the
# same script can be run idempotently from any machine that has AWS creds.
#
# Subcommands:
#   up        Create the instance (and SG + key pair) if it doesn't exist.
#             Prints the public IP and the SSH command at the end.
#   status    Show id, state, public IP.
#   ssh       SSH into the instance using the generated key.
#   stop      Stop (preserves disk; cheap; restartable).
#   start     Start a previously stopped instance.
#   down      Terminate the instance (asks for confirmation).
#   nuke      Terminate + delete the security group and key pair.
#
# Requires: aws cli v2, jq.
# Uses your current AWS creds (env / `aws configure` / SSO). The profile is
# read from AWS_PROFILE (or AWS_DEFAULT_PROFILE); region from AWS_REGION,
# AWS_DEFAULT_REGION, or `aws configure get region`.
#
# Typical SSO flow:
#   aws sso login --profile alpha
#   AWS_PROFILE=alpha ./aws-setup.sh deploy
# Or use the Makefile in this folder:  make deploy ENV=alpha

set -euo pipefail

# ----- config (override via env) --------------------------------------------
# Personal prefix on every AWS resource so you can tell what's yours at a glance.
PREFIX="${PREFIX:-vj}"

INSTANCE_NAME="${INSTANCE_NAME:-${PREFIX}-agent-interview}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.medium}"
VOLUME_SIZE_GB="${VOLUME_SIZE_GB:-30}"
SG_NAME="${SG_NAME:-${INSTANCE_NAME}-sg}"
KEY_NAME="${KEY_NAME:-${INSTANCE_NAME}-key}"
KEY_FILE="${KEY_FILE:-$HOME/.ssh/${KEY_NAME}.pem}"
# SSH ingress CIDR. Default: auto-detect this machine's current public IP and
# lock to /32. Many AWS orgs auto-revoke any 22/tcp rule with source 0.0.0.0/0,
# so we re-authorize from the current IP on every run. Override with
# SSH_CIDR=1.2.3.4/32 (or 0.0.0.0/0 if your account allows it).
detect_my_ip() {
    local ip
    ip="$(curl -fsS --max-time 5 https://checkip.amazonaws.com 2>/dev/null \
        || curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null \
        || true)"
    ip="${ip//[$'\r\n ']}"
    [[ "$ip" =~ ^[0-9.]+$ ]] || return 1
    echo "${ip}/32"
}
if [[ -z "${SSH_CIDR:-}" ]]; then
    SSH_CIDR="$(detect_my_ip)" || SSH_CIDR="0.0.0.0/0"
fi
TAG_KEY="Name"
OWNER_TAG_KEY="Owner"
OWNER_TAG_VALUE="${OWNER_TAG_VALUE:-${PREFIX}}"

# AWS profile (SSO or otherwise). If neither AWS_PROFILE nor AWS_DEFAULT_PROFILE
# is set we just rely on whatever creds the env/instance role provides.
PROFILE="${AWS_PROFILE:-${AWS_DEFAULT_PROFILE:-}}"
if [[ -n "$PROFILE" ]]; then
    export AWS_PROFILE="$PROFILE" AWS_DEFAULT_PROFILE="$PROFILE"
fi

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region 2>/dev/null || true)}}"
if [[ -z "$REGION" ]]; then
    echo "ERROR: no AWS region. Set AWS_REGION or run 'aws configure'." >&2
    exit 1
fi
export AWS_REGION="$REGION" AWS_DEFAULT_REGION="$REGION"

# ----- helpers --------------------------------------------------------------
log()   { echo "[aws-setup] $*" >&2; }
fail()  { echo "[aws-setup] ERROR: $*" >&2; exit 1; }
need()  { command -v "$1" >/dev/null || fail "missing dependency: $1"; }

need aws
need jq

# Verify creds are valid up-front; for SSO this catches an expired session
# before we try to do anything destructive. Skipped if no profile is set
# (assume env vars / instance role).
if [[ -n "$PROFILE" ]]; then
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        fail "AWS creds invalid or expired for profile '$PROFILE'. Run: aws sso login --profile $PROFILE"
    fi
    log "using AWS profile=$PROFILE region=$REGION"
else
    log "using AWS region=$REGION (no profile set; using env/role creds)"
fi

confirm() {
    local prompt="$1" reply
    read -r -p "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Returns instance id of the most recent non-terminated instance with our tag,
# or empty string if none exists.
find_instance() {
    aws ec2 describe-instances \
        --filters "Name=tag:${TAG_KEY},Values=${INSTANCE_NAME}" \
                  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
        --query 'Reservations[].Instances[] | sort_by(@, &LaunchTime) | [-1].InstanceId' \
        --output text 2>/dev/null | grep -v '^None$' || true
}

instance_state() {
    local id="$1"
    aws ec2 describe-instances --instance-ids "$id" \
        --query 'Reservations[0].Instances[0].State.Name' --output text
}

instance_ip() {
    local id="$1"
    aws ec2 describe-instances --instance-ids "$id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
}

ensure_key_pair() {
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
        log "key pair $KEY_NAME exists"
        [[ -f "$KEY_FILE" ]] || fail "key pair $KEY_NAME exists in AWS but $KEY_FILE is missing locally; delete it in AWS or restore the .pem"
    else
        log "creating key pair $KEY_NAME -> $KEY_FILE"
        mkdir -p "$(dirname "$KEY_FILE")"
        aws ec2 create-key-pair --key-name "$KEY_NAME" \
            --query 'KeyMaterial' --output text > "$KEY_FILE"
        chmod 600 "$KEY_FILE"
    fi
}

ensure_security_group() {
    local sg_id
    sg_id="$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=${SG_NAME}" \
        --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"

    if [[ -z "$sg_id" || "$sg_id" == "None" ]]; then
        log "creating security group $SG_NAME"
        sg_id="$(aws ec2 create-security-group \
            --group-name "$SG_NAME" \
            --description "Interview EC2 (code-server + Caddy)" \
            --query 'GroupId' --output text)"
    else
        log "security group $SG_NAME exists ($sg_id)"
    fi

    # Idempotently ensure 22/80/443 are open. AWS returns
    # InvalidPermission.Duplicate if a rule already exists; ignore that.
    ensure_ingress() {
        local port="$1" cidr="$2"
        aws ec2 authorize-security-group-ingress --group-id "$sg_id" \
            --protocol tcp --port "$port" --cidr "$cidr" >/dev/null 2>&1 \
            || true
    }

    # SSH: revoke any stale /32 rules pointing at an old IP, then add the
    # current one. This keeps the SG clean as your home/office IP changes.
    if [[ "$SSH_CIDR" != "0.0.0.0/0" ]]; then
        local stale
        stale="$(aws ec2 describe-security-groups --group-ids "$sg_id" \
            --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`].IpRanges[].CidrIp" \
            --output text 2>/dev/null || true)"
        for cidr in $stale; do
            [[ "$cidr" == "$SSH_CIDR" ]] && continue
            log "revoking stale SSH ingress $cidr"
            aws ec2 revoke-security-group-ingress --group-id "$sg_id" \
                --protocol tcp --port 22 --cidr "$cidr" >/dev/null 2>&1 || true
        done
    fi
    log "SSH ingress: ${SSH_CIDR}"
    ensure_ingress 22  "${SSH_CIDR}"
    ensure_ingress 80  "0.0.0.0/0"
    ensure_ingress 443 "0.0.0.0/0"

    echo "$sg_id"
}

latest_ubuntu_ami() {
    # Canonical's Ubuntu 22.04 LTS amd64 (hvm:ebs-ssd) latest, via SSM.
    aws ssm get-parameter \
        --name /aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id \
        --query 'Parameter.Value' --output text
}

user_data() {
    cat <<'EOF'
#!/usr/bin/env bash
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

# Wait for any concurrent apt run (unattended-upgrades fires on first boot
# and grabs the dpkg lock for ~30-90s; without this we race and lose).
wait_apt() {
    for _ in $(seq 1 60); do
        if ! fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/apt/lists/lock >/dev/null 2>&1; then
            return 0
        fi
        sleep 5
    done
    echo "WARN: apt locks never released after 5min" >&2
}

# Retry apt-get a few times — transient mirror flakes happen on fresh boots.
apt_run() {
    for i in 1 2 3 4 5; do
        wait_apt
        if apt-get "$@"; then return 0; fi
        echo "apt-get $* failed (attempt $i); retrying in 10s" >&2
        sleep 10
    done
    return 1
}

apt_run update
apt_run install -y ca-certificates curl gnupg git make

# Docker (official convenience script).
wait_apt
curl -fsSL https://get.docker.com | sh
usermod -aG docker ubuntu

# Sentinel that the deploy script polls for.
echo "ec2 bootstrap done" > /var/log/interview-bootstrap.done
EOF
}

# ----- subcommands ----------------------------------------------------------
cmd_up() {
    local existing
    existing="$(find_instance)"
    if [[ -n "$existing" ]]; then
        log "instance already exists: $existing ($(instance_state "$existing"))"
        # Still self-heal SG rules — your IP may have changed, or a guardrail
        # may have revoked port 22.
        ensure_security_group >/dev/null
        return 0
    fi

    ensure_key_pair
    local sg_id; sg_id="$(ensure_security_group)"
    local ami;   ami="$(latest_ubuntu_ami)"
    local ud;    ud="$(user_data | base64 | tr -d '\n')"

    log "launching $INSTANCE_TYPE in $REGION (ami $ami)"
    local id
    id="$(aws ec2 run-instances \
        --image-id "$ami" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$sg_id" \
        --user-data "$ud" \
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=${VOLUME_SIZE_GB},VolumeType=gp3}" \
        --tag-specifications \
            "ResourceType=instance,Tags=[{Key=${TAG_KEY},Value=${INSTANCE_NAME}},{Key=${OWNER_TAG_KEY},Value=${OWNER_TAG_VALUE}}]" \
            "ResourceType=volume,Tags=[{Key=${TAG_KEY},Value=${INSTANCE_NAME}},{Key=${OWNER_TAG_KEY},Value=${OWNER_TAG_VALUE}}]" \
        --query 'Instances[0].InstanceId' --output text)"

    log "waiting for $id to be running…"
    aws ec2 wait instance-running --instance-ids "$id"
    aws ec2 wait instance-status-ok --instance-ids "$id" || true

    local ip; ip="$(instance_ip "$id")"
    cat >&2 <<EOF

[aws-setup] up.
  instance:  $id
  public ip: $ip
  ssh:       ssh -i $KEY_FILE ubuntu@$ip

(cloud-init is still installing docker on the box — takes ~60s.
 If you want the full app deployed, use \`./aws-setup.sh deploy\` instead.)
EOF
}

cmd_status() {
    local id; id="$(find_instance)"
    if [[ -z "$id" ]]; then
        log "no instance tagged ${TAG_KEY}=${INSTANCE_NAME}"
        return 0
    fi
    local state ip
    state="$(instance_state "$id")"
    ip="$(instance_ip "$id")"
    printf "instance: %s\nstate:    %s\npublic ip: %s\n" "$id" "$state" "$ip"
}

cmd_ssh() {
    local id; id="$(find_instance)" || true
    [[ -n "$id" ]] || fail "no instance found"
    local ip; ip="$(instance_ip "$id")"
    [[ "$ip" != "None" && -n "$ip" ]] || fail "instance has no public IP (state=$(instance_state "$id"))"
    exec ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new "ubuntu@$ip"
}

cmd_stop() {
    local id; id="$(find_instance)" || true
    [[ -n "$id" ]] || fail "no instance found"
    confirm "Stop $id? (disk preserved, restartable)" || return 0
    aws ec2 stop-instances --instance-ids "$id" >/dev/null
    aws ec2 wait instance-stopped --instance-ids "$id"
    log "stopped $id"
}

cmd_start() {
    local id; id="$(find_instance)" || true
    [[ -n "$id" ]] || fail "no instance found"
    aws ec2 start-instances --instance-ids "$id" >/dev/null
    aws ec2 wait instance-running --instance-ids "$id"
    log "running: $id  ip: $(instance_ip "$id")"
}

cmd_down() {
    local id; id="$(find_instance)" || true
    [[ -n "$id" ]] || { log "nothing to terminate"; return 0; }
    confirm "TERMINATE $id (DESTROYS disk, irreversible)?" || return 0
    aws ec2 terminate-instances --instance-ids "$id" >/dev/null
    aws ec2 wait instance-terminated --instance-ids "$id"
    log "terminated $id"
}

cmd_nuke() {
    cmd_down
    if confirm "Also delete security group $SG_NAME and key pair $KEY_NAME?"; then
        aws ec2 delete-security-group --group-name "$SG_NAME" 2>/dev/null \
            && log "deleted SG $SG_NAME" || log "SG $SG_NAME not found"
        aws ec2 delete-key-pair --key-name "$KEY_NAME" 2>/dev/null \
            && log "deleted key pair $KEY_NAME" || log "key pair $KEY_NAME not found"
        rm -f "$KEY_FILE" && log "removed local $KEY_FILE" || true
    fi
}

# Compute the URL Caddy will serve on. Default: <dashed-ip>.sslip.io so we get
# a real Let's Encrypt cert with zero DNS setup. Override with INTERVIEW_DOMAIN.
compute_domain() {
    local ip="$1"
    if [[ -n "${INTERVIEW_DOMAIN:-}" ]]; then
        echo "$INTERVIEW_DOMAIN"
    else
        echo "${ip//./-}.sslip.io"
    fi
}

ssh_to() {
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        "ubuntu@$1" "$@:2"
}

run_remote() {
    local ip="$1"; shift
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new \
        -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        "ubuntu@$ip" "$@"
}

# End-to-end: create instance (idempotent), clone the repo from GitHub on the
# box, write .env, run docker compose, print the candidate URL + password.
cmd_deploy() {
    # If the operator hasn't exported OPENAI_API_KEY (and friends) in their
    # shell, fall back to the repo-root .env so `make aws-deploy` Just Works.
    local repo_root; repo_root="$(cd "$(dirname "$0")/.." && pwd)"
    if [[ -f "$repo_root/.env" ]]; then
        log "loading $repo_root/.env"
        set -a; . "$repo_root/.env"; set +a
    fi

    [[ -n "${OPENAI_API_KEY:-}" ]] || fail "OPENAI_API_KEY not set (export it or put it in $repo_root/.env)"
    [[ -n "${REPO_URL:-}" ]] || fail "REPO_URL not set (e.g. https://github.com/you/agent-interview.git — export it or put it in $repo_root/.env)"
    local repo_ref="${REPO_REF:-main}"

    cmd_up
    local id; id="$(find_instance)"
    local ip; ip="$(instance_ip "$id")"

    log "waiting for ssh on $ip"
    for _ in {1..30}; do
        ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new \
            -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
            -o ConnectTimeout=5 "ubuntu@$ip" true 2>/dev/null && break
        sleep 5
    done

    log "waiting for cloud-init to finish installing docker"
    run_remote "$ip" "bash -lc '
        for _ in {1..60}; do
            [[ -f /var/log/interview-bootstrap.done ]] && exit 0
            sleep 5
        done
        echo cloud-init never finished >&2
        exit 1
    '"

    local domain; domain="$(compute_domain "$ip")"
    local password="${CODE_SERVER_PASSWORD:-$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-20)}"
    local model="${OPENAI_MODEL:-gpt-5.1}"
    local acme_email="${ACME_EMAIL:-admin@${domain}}"

    log "cloning $REPO_URL ($repo_ref) into /workspace on the box"
    run_remote "$ip" "bash -lc '
        set -euo pipefail
        if [[ -d /workspace/.git ]]; then
            cd /workspace
            sudo git fetch --depth=1 origin $repo_ref
            sudo git reset --hard origin/$repo_ref
        else
            sudo rm -rf /workspace
            sudo git clone --depth=1 --branch $repo_ref $REPO_URL /workspace
        fi
        sudo chown -R ubuntu:ubuntu /workspace
    '"

    log "writing /workspace/ec2/.env on the box"
    run_remote "$ip" "bash -lc '
        set -euo pipefail
        cd /workspace/ec2
        cat > .env <<ENVEOF
INTERVIEW_DOMAIN=$domain
ACME_EMAIL=$acme_email
CODE_SERVER_PASSWORD=$password
OPENAI_API_KEY=$OPENAI_API_KEY
OPENAI_MODEL=$model
ENVEOF
        chmod 600 .env

        sg docker -c \"docker compose up -d --build\"
    '"

    cat >&2 <<EOF

[aws-setup] DEPLOYED.
  url:      https://$domain
  password: $password
  ssh:      ssh -i $KEY_FILE ubuntu@$ip

share the URL + password with the candidate. Caddy is fetching a Let's
Encrypt cert in the background; first load may take ~30s.

between candidates:  ./aws-setup.sh reset
when done:           ./aws-setup.sh stop      (cheap pause)
                     ./aws-setup.sh down      (terminate)
EOF
}

cmd_url() {
    local id; id="$(find_instance)" || true
    [[ -n "$id" ]] || fail "no instance found"
    local ip; ip="$(instance_ip "$id")"
    local domain; domain="$(compute_domain "$ip")"

    if pw="$(run_remote "$ip" 'grep -E ^CODE_SERVER_PASSWORD= /workspace/ec2/.env 2>/dev/null | cut -d= -f2-')" && [[ -n "$pw" ]]; then
        printf "url:      https://%s\npassword: %s\n" "$domain" "$pw"
    else
        printf "url:      https://%s\n(no .env found on box \u2014 run \`./aws-setup.sh deploy\` first)\n" "$domain"
    fi
}

cmd_reset() {
    local id; id="$(find_instance)" || true
    [[ -n "$id" ]] || fail "no instance found"
    local ip; ip="$(instance_ip "$id")"
    log "resetting code-server workspace on $ip"
    run_remote "$ip" "sg docker -c 'bash /workspace/ec2/reset.sh'"
    log "done. Same URL + password as before."
}

# ----- dispatch -------------------------------------------------------------
case "${1:-}" in
    up)      cmd_up ;;
    deploy)  cmd_deploy ;;
    url)     cmd_url ;;
    status)  cmd_status ;;
    ssh)     cmd_ssh ;;
    reset)   cmd_reset ;;
    stop)    cmd_stop ;;
    start)   cmd_start ;;
    down)    cmd_down ;;
    nuke)    cmd_nuke ;;
    *)
        cat <<EOF
usage: $0 <deploy|url|status|reset|ssh|up|stop|start|down|nuke>

high-level:
  deploy   end-to-end: create EC2 (if missing), rsync repo, write .env,
           start docker compose, print URL + password
  url      print the candidate URL + password for the running instance
  reset    discard candidate edits, clear history, restart code-server
  status   id / state / public IP

low-level:
  up       create instance only (no app deploy)
  ssh      open a shell on the box
  stop     pause (disk preserved)
  start    resume
  down     terminate (confirm)
  nuke     terminate + delete SG + key pair (confirm)

env overrides:
  AWS_PROFILE        SSO/credentials profile to use       [${PROFILE:-<none>}]
  AWS_REGION                                              [$REGION]
  PREFIX             personal prefix on resource names    [$PREFIX]
  INSTANCE_NAME      tag used to identify the box         [$INSTANCE_NAME]
  INSTANCE_TYPE                                           [$INSTANCE_TYPE]
  VOLUME_SIZE_GB                                          [$VOLUME_SIZE_GB]
  SSH_CIDR           CIDR allowed to reach port 22        [$SSH_CIDR]
  REPO_URL           public git URL the box clones        (required for deploy)
  REPO_REF           branch/tag/sha to check out          [main]
  INTERVIEW_DOMAIN   override default <ip>.sslip.io URL
  CODE_SERVER_PASSWORD  override generated password
  OPENAI_API_KEY     required for 'deploy'
  OPENAI_MODEL                                            [gpt-5.1]
  ACME_EMAIL         Let's Encrypt notifications email
EOF
        exit 1 ;;
esac
