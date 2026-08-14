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

## Test it on your account

The Terraform is already validated (`terraform validate` **and** a full
`terraform plan` pass against the real UpCloud provider v5.43 schema), so a first
run is low-risk. Confirm the account-specific values (zone, plan, and OS-template
title) in the UpCloud control panel or via the `upctl` CLI — the defaults in
`terraform.tfvars.example` match common values — then do a throwaway loop:

```bash
make validate   # config check (already known-good)
make plan       # preview exactly what will be created — read it
make apply      # create the server
make output     # get the IP; open the web UI from your admin IP
make destroy    # tear it all down
```

The whole thing is billed by the hour on UpCloud, so a test apply→destroy costs
a few cents.

---

## Day-of-operation

### 1. Launch
```bash
make apply        # ~30s to create the server; cloud-init then installs the stack
make output       # shows the public IP and web UI URL
make bootstrap-log  # optional: watch the install finish (~5-8 min)
```

### 2. Configure users
1. Open `https://<ip>` from your admin IP (port 443 is locked to `admin_ips` by
   default). Accept the self-signed cert.
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

## Security hardening

In place by default:

- **Admin plane locked down.** SSH (22), the web admin UI / CloudTAK (443), and
  ping are reachable only from `admin_ips`. Only the TAK client ports —
  8089 (CoT/TLS), 8443 (API/data), 8446 (enrollment) — are open to the internet,
  because field devices connect from arbitrary networks.
- **Default-credential window closed at the network layer.** Since 443 is
  admin-only by default, OpenTAKServer's default login page is never exposed to
  the world before you change the password. (If you flip
  `open_web_ui_to_world = true` for the browser client, change the password
  *first*.)
- **Key-only SSH.** Password and root login disabled (`ssh_pwauth: false` plus an
  sshd drop-in: `PermitRootLogin no`, `PasswordAuthentication no`,
  `KbdInteractiveAuthentication no`, `MaxAuthTries 3`). You log in as the
  non-root `takadmin` user.
- **Automatic security updates** via `unattended-upgrades`, with pending patches
  applied on first boot.
- **Default-deny inbound firewall** (IPv4 + IPv6) at the UpCloud platform layer.
  It's stateful, so the server can still pull Docker images / updates outbound.
- **Unused ports closed:** 80 (Let's Encrypt), 8080 (internal API), and 8883
  (MQTT) are not exposed unless you add them.

Residual items worth knowing:

- **Self-signed TLS by default** — clients see a cert warning. For a trusted
  cert, point a domain at the server, open port 80, and enable Let's Encrypt in
  the OTS config.
- **Containers run as root** inside Docker (upstream OTS packaging); the host
  user is non-root, but container isolation is the boundary.
- **Keep `admin_ips` tight** — a single address is best; a wide range widens who
  can reach SSH and the admin UI.

## Notes & caveats

- The Terraform is validated (`terraform validate` + a full `terraform plan`
  against the real UpCloud provider v5.43 schema). It has **not** been applied
  end-to-end against a live account from here, so confirm the exact zone / plan /
  OS-template names for your account and do one throwaway `apply`/`destroy` first.
- **Pin `compose_ref`** to a tag/commit you've validated — don't run an operation
  off a moving `master`. OpenTAKServer's Docker packaging is young.
- To switch to prebuilt images or the official TAK Server, see
  [`docs/deployment-options.md`](docs/deployment-options.md).
