# Turnkey wrappers around Terraform. Run `make help` for the list.
# Requires: terraform (or tofu), and UPCLOUD_USERNAME / UPCLOUD_PASSWORD in env.
# New here? Run `make doctor` first, then follow the README's numbered setup.

TF      ?= terraform
TF_DIR  := terraform
TF_RUN  := $(TF) -chdir=$(TF_DIR)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: check-creds
check-creds:
	@test -n "$$UPCLOUD_USERNAME" || { echo "ERROR: UPCLOUD_USERNAME not set (see README step 2)"; exit 1; }
	@test -n "$$UPCLOUD_PASSWORD" || { echo "ERROR: UPCLOUD_PASSWORD not set (see README step 2)"; exit 1; }

.PHONY: configure
configure: ## Scaffold terraform/terraform.tfvars from the template
	@if [ -f $(TF_DIR)/terraform.tfvars ]; then \
	  echo "$(TF_DIR)/terraform.tfvars already exists — leaving it untouched."; \
	else \
	  cp $(TF_DIR)/terraform.tfvars.example $(TF_DIR)/terraform.tfvars; \
	  echo "Created $(TF_DIR)/terraform.tfvars."; \
	  echo "Edit it now: ssh_public_keys, admin_ips (see 'make doctor'), zone, plan, compose_ref."; \
	fi

.PHONY: doctor
doctor: ## Preflight: check tools, credentials, config, and show your public IP
	@echo "TAK deployment preflight"; echo "------------------------"
	@if command -v terraform >/dev/null 2>&1; then echo "[ok]  $$(terraform version | head -1)"; \
	 elif command -v tofu >/dev/null 2>&1; then echo "[ok]  $$(tofu version | head -1)"; \
	 else echo "[--]  terraform/opentofu NOT installed (see README step 1)"; fi
	@command -v ssh >/dev/null 2>&1 && echo "[ok]  ssh present" || echo "[--]  ssh not found"
	@if [ -n "$$UPCLOUD_USERNAME" ] && [ -n "$$UPCLOUD_PASSWORD" ]; then \
	  echo "[ok]  UpCloud API credentials set in this shell"; \
	 else echo "[--]  UPCLOUD_USERNAME / UPCLOUD_PASSWORD not set (see README step 2)"; fi
	@if [ -f $(TF_DIR)/terraform.tfvars ]; then echo "[ok]  $(TF_DIR)/terraform.tfvars present"; \
	 else echo "[--]  $(TF_DIR)/terraform.tfvars missing — run: make configure"; fi
	@if ls $$HOME/.ssh/*.pub >/dev/null 2>&1; then \
	  echo "[ok]  SSH public key(s): $$(ls $$HOME/.ssh/*.pub | tr '\n' ' ')"; \
	 else echo "[--]  no SSH public key in ~/.ssh — run: ssh-keygen -t ed25519"; fi
	@ip=$$(curl -fsS --max-time 5 https://api.ipify.org 2>/dev/null); \
	 if [ -n "$$ip" ]; then echo "[ip]  your public IP is $$ip  — put this in admin_ips"; \
	 else echo "[ip]  could not detect public IP (check manually: curl ifconfig.me)"; fi

.PHONY: init
init: ## Download the UpCloud provider (run once per clone)
	$(TF_RUN) init

.PHONY: fmt
fmt: ## Format the Terraform files
	$(TF_RUN) fmt

.PHONY: validate
validate: ## Validate the Terraform config
	$(TF_RUN) validate

.PHONY: plan
plan: check-creds ## Preview exactly what will be created/changed
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
bootstrap-log: ## Watch the first-boot install log (until you see 'stack up')
	ssh takadmin@$$($(TF_RUN) output -raw server_ip) 'sudo tail -f /var/log/tak-bootstrap.log'

.PHONY: status
status: ## Show running containers on the server
	ssh takadmin@$$($(TF_RUN) output -raw server_ip) 'cd /opt/tak/stack && docker compose ps'

.PHONY: logs
logs: ## Tail the TAK stack logs
	ssh takadmin@$$($(TF_RUN) output -raw server_ip) 'cd /opt/tak/stack && docker compose logs -f --tail=100'
