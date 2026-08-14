# Turnkey wrappers around Terraform. Run `make help` for the list.
# Requires: terraform (or tofu), and UPCLOUD_USERNAME / UPCLOUD_PASSWORD in env.

TF      ?= terraform
TF_DIR  := terraform
TF_RUN  := $(TF) -chdir=$(TF_DIR)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: check-creds
check-creds:
	@test -n "$$UPCLOUD_USERNAME" || { echo "ERROR: export UPCLOUD_USERNAME"; exit 1; }
	@test -n "$$UPCLOUD_PASSWORD" || { echo "ERROR: export UPCLOUD_PASSWORD"; exit 1; }

.PHONY: init
init: ## terraform init (run once)
	$(TF_RUN) init

.PHONY: fmt
fmt: ## Format the Terraform files
	$(TF_RUN) fmt

.PHONY: validate
validate: ## Validate the Terraform config
	$(TF_RUN) validate

.PHONY: plan
plan: check-creds ## Preview changes
	$(TF_RUN) plan

.PHONY: apply
apply: check-creds ## Create/update the server (stand up the operation)
	$(TF_RUN) apply

.PHONY: destroy
destroy: check-creds ## Scorched earth — delete the server and all data
	$(TF_RUN) destroy

.PHONY: output
output: ## Show the server IP / web UI URL / ssh command
	$(TF_RUN) output

.PHONY: ssh
ssh: ## SSH into the server as takadmin
	ssh takadmin@$$($(TF_RUN) output -raw server_ip)

.PHONY: bootstrap-log
bootstrap-log: ## Tail the first-boot install log
	ssh takadmin@$$($(TF_RUN) output -raw server_ip) 'sudo tail -f /var/log/tak-bootstrap.log'

.PHONY: status
status: ## Show running containers on the server
	ssh takadmin@$$($(TF_RUN) output -raw server_ip) 'cd /opt/tak/stack && docker compose ps'

.PHONY: logs
logs: ## Tail the TAK stack logs
	ssh takadmin@$$($(TF_RUN) output -raw server_ip) 'cd /opt/tak/stack && docker compose logs -f --tail=100'
