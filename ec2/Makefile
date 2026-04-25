# Operator-only targets for the interview EC2 box. Wraps aws-setup.sh and
# pins AWS_PROFILE to the SSO profile passed via ENV=...
#
# Run from this directory:        make deploy ENV=alpha
# Or from the repo root:          make aws-deploy ENV=alpha   (forwards here)
#
# Targets:
#   make login   ENV=alpha   aws sso login --profile alpha
#   make deploy  ENV=alpha   end-to-end: EC2 + rsync + compose up
#   make url     ENV=alpha   print URL + password
#   make reset   ENV=alpha   between-candidate cleanup
#   make status|ssh|stop|start|down|nuke ENV=alpha

ENV ?= alpha
AWS := AWS_PROFILE=$(ENV) AWS_DEFAULT_PROFILE=$(ENV)

.PHONY: help login deploy url status reset ssh stop start down nuke

help:
	@echo "Targets (all take ENV=<sso-profile>, default $(ENV)):"
	@echo "  make login   ENV=alpha    aws sso login --profile <env>"
	@echo "  make deploy  ENV=alpha    end-to-end: EC2 + rsync + compose up"
	@echo "  make url     ENV=alpha    print candidate URL + password"
	@echo "  make reset   ENV=alpha    between-candidate cleanup"
	@echo "  make status|ssh|stop|start|down|nuke ENV=alpha"

login:
	AWS_PROFILE=$(ENV) aws sso login

deploy url status reset ssh stop start down nuke:
	$(AWS) ./aws-setup.sh $@
