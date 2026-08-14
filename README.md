# TAK Server — turnkey ephemeral deployment (UpCloud)

Stand up a TAK server for an operation with **one command**, and wipe it with
another. No installer patching, no interactive scripts — Docker Compose on a
declaratively-provisioned UpCloud server.

- **Server:** OpenTAKServer (web UI, username/password, downloadable data
  packages, CloudTAK browser client). Runs as a pinned docker compose stack.
- **Infra:** UpCloud via Terraform + cloud-init. Helsinki zone for low latency.
- **Model:** ephemeral. `make apply` to stand up, `make destroy` for scorched earth.

Why it was rebuilt and what the alternatives are: see
[`docs/deployment-options.md`](docs/deployment-options.md). The previous scripts
are preserved under [`legacy/`](legacy/).

---

## Prerequisites (one-time)

1. **UpCloud account** with an **API-enabled sub-account** (control panel →
   People → add a sub-account, tick API access). Never use your main login for
   automation.
2. **Terraform** ≥ 1.5 (or OpenTofu) and **make** on your laptop.
3. An **SSH key pair** (`ssh-keygen -t ed25519` if you don't have one).

```bash
export UPCLOUD_USERNAME="your-api-subaccount"
export UPCLOUD_PASSWORD="your-api-subaccount-password"
```

## Configure (one-time)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: paste your SSH public key, set admin_ips to your
# public IP (curl ifconfig.me), pick a zone/plan, and PIN compose_ref.
cd ..
make init
```

---

## Day-of-operation

### 1. Launch
```bash
make apply        # ~30s to create the server; cloud-init then installs the stack
make output       # shows the public IP and web UI URL
make bootstrap-log  # optional: watch the install finish (~5-8 min)
```

### 2. Configure users
1. Open `https://<ip>` (the web UI / CloudTAK). Accept the self-signed cert.
2. Log in with the OpenTAKServer default admin account and **change the password
   immediately**.
3. Create user accounts.
4. Download each user's **data package** (`.zip`) and send it to the team to
   import into ATAK / iTAK / WinTAK.

### 3. End of operation (scorched earth)
```bash
make destroy      # deletes the server and every byte of data
```

---

## Handy commands

```bash
make status   # docker compose ps on the server
make logs     # tail the stack logs
make ssh      # shell in as takadmin
make plan     # preview infra changes
make help     # full list
```

---

## How it fits together

```
terraform/   UpCloud server + platform firewall
  main.tf, variables.tf, outputs.tf, versions.tf, terraform.tfvars.example
cloud-init/  first-boot: install Docker, pull the PINNED compose stack, start it
  user-data.yaml.tftpl
Makefile     operator wrappers (apply/destroy/ssh/logs/status/...)
docs/        options analysis + decision record
legacy/      the previous GCP/installer-patching attempts (kept for reference)
```

## Notes & honest caveats

- The **firewall** opens only the TAK client/web ports to the internet
  (443, 8443, 8446, 8089, 8883); **SSH (22) is restricted to `admin_ips`**.
- **Pin `compose_ref`** to a tag/commit you've validated before a real op —
  don't deploy off a moving `master`.
- OpenTAKServer's Docker packaging is young; validate a pinned ref once. To
  switch to prebuilt images or the official TAK Server, see
  [`docs/deployment-options.md`](docs/deployment-options.md).
- This Terraform has not been applied against a live UpCloud account from CI;
  run `make validate` and a `make plan` first, and expect to confirm exact zone
  / plan / OS-template names for your account (`upctl zone list`,
  `upctl plan list`, `upctl storage list --template`).
