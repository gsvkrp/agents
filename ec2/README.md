# EC2 + code-server interview setup

Self-hosted alternative to Codespaces. Candidate gets one HTTPS URL and a
password — they see VS Code in their browser, no GitHub repo.

## Architecture

```
candidate browser
   │ HTTPS (real Let's Encrypt cert)
   ▼
Caddy ───► code-server (VS Code in browser)
                │
                ▼
        /workspace (your code, .git/ hidden)
```

`entrypoint.sh` moves `.git/` to `/root/.git-stash` before code-server starts,
so the candidate sees no remote, no commits, no branches. `reset.sh`
restores `.git/`, discards their edits, hides `.git/` again, and restarts the
container.

## One command to deploy

You're AWS-logged-in (env / `aws configure` / SSO) and have `OPENAI_API_KEY`
exported in your shell? Then:

```bash
export OPENAI_API_KEY=sk-...
./aws-setup.sh deploy
```

That single command:

1. Creates the EC2 instance (or reuses one tagged `Name=vj-agent-interview`).
2. Waits for cloud-init to install Docker.
3. `rsync`s the repo from your laptop to the box (no `git clone`, so the repo
   doesn't have to be public or accessible from the EC2).
4. Generates a random `code-server` password.
5. Computes the URL — by default `https://<dashed-ip>.sslip.io` (no DNS
   setup, real Let's Encrypt cert; override with `INTERVIEW_DOMAIN=...`).
6. Writes `.env` on the box and runs `docker compose up -d --build`.
7. Prints the URL + password to share with the candidate.

First load takes ~30 s while Caddy fetches the cert.

## Day-to-day commands

```bash
./aws-setup.sh deploy   # full pipeline (idempotent — safe to re-run)
./aws-setup.sh url      # print URL + password again
./aws-setup.sh reset    # between candidates: wipe edits + history
./aws-setup.sh status   # id / state / public IP
./aws-setup.sh ssh      # shell on the box
./aws-setup.sh stop     # cheap pause (disk preserved, restartable)
./aws-setup.sh start    # resume
./aws-setup.sh down     # terminate (confirm)
./aws-setup.sh nuke     # terminate + delete SG + key pair (confirm)
```

All AWS resources (instance, volume, SG, key pair) carry the `vj-` prefix
and an `Owner=vj` tag. Override with `PREFIX=...` or `INSTANCE_NAME=...`.

## Per-candidate flow

```bash
./aws-setup.sh deploy   # first time
./aws-setup.sh url      # share output with candidate

# (interview happens)

./aws-setup.sh reset    # before next candidate
./aws-setup.sh url      # same URL + password, fresh workspace
```

When done for the day: `./aws-setup.sh stop`. When done for good:
`./aws-setup.sh nuke`.

## What the candidate sees

- A `/workspace` folder with the exercise files.
- No `.git/`, no Source Control panel, no `git remote -v`.
- A working terminal: `make test`, `make repl`, `make run`.
- `OPENAI_API_KEY` in their env (visible via `echo $OPENAI_API_KEY`).
  Rotate after the interview if that matters.

## URL options

| You set                                        | URL                                        | DNS work | TLS               |
|------------------------------------------------|--------------------------------------------|----------|-------------------|
| nothing (default)                              | `https://54-234-12-56.sslip.io`            | none     | real Let's Encrypt |
| `INTERVIEW_DOMAIN=interview.example.com`       | `https://interview.example.com`            | A record → IP | real Let's Encrypt |

## Hardening (optional)

- **Hide the API key:** front OpenAI with [LiteLLM proxy](https://github.com/BerriAI/litellm)
  on the same EC2; give the candidate a fake key + `OPENAI_BASE_URL` pointing
  at the proxy. Real key lives in the proxy container.
- **Per-candidate isolation:** run multiple `code-server` containers under
  different subdomains (`a.interview…`, `b.interview…`) and route in the
  `Caddyfile`. Each gets its own workspace volume.
- **Read-only base layer:** mount `/workspace` from a tmpfs/overlay so reset
  is instant and there's nothing to discard.


===

make aws-login  ENV=alpha     # 1. SSO session (~8h)
make aws-deploy ENV=alpha     # 2. deploy (reads .env automatically)

# when done:
make aws-stop ENV=alpha       # cheap pause (disk preserved, ~$3/mo)
make aws-down ENV=alpha       # terminate (full delete)