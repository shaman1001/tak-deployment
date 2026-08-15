# TAK Server — turnkey ephemeral deployment (UpCloud)

Stand up an OpenTAKServer for an operation, hand out data packages to your team,
and wipe the whole thing when you're done. No installer patching, no interactive
scripts — a pinned Docker Compose stack on a declaratively-provisioned UpCloud
server.

- **Server:** OpenTAKServer — web UI, username/password logins, an
  auto-generated CA that issues each user's client certificate as a data package,
  and the CloudTAK browser client.
- **Infra:** UpCloud via Terraform + cloud-init. Helsinki zone for low latency.
- **Model:** ephemeral. Build it for the op, `make destroy` after.

Background reading (optional): [`docs/deployment-options.md`](docs/deployment-options.md)
explains why it's built this way and what the alternatives are. The previous
scripts are preserved under [`legacy/`](legacy/).

---

## Setup — from zero to a running server

**Steps 1–3 are one-time. Steps 4–7 are the per-operation loop.**
At any point, run `make doctor` to check what's done and what's missing.

### Step 1 — Install the tools (one-time)

You need **Terraform** (or OpenTofu), **make**, **git**, and **ssh** on your
laptop.

<details>
<summary>macOS (Homebrew)</summary>

```bash
brew install terraform make git
```
</details>

<details>
<summary>Ubuntu / Debian</summary>

```bash
sudo apt-get update && sudo apt-get install -y make git curl
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
```
</details>

If you don't already have an SSH key, create one (press Enter through the
prompts):

```bash
ssh-keygen -t ed25519
```

### Step 2 — Get UpCloud API credentials (one-time)

Terraform talks to UpCloud through a dedicated API user — never your main login.

1. Sign in to the **UpCloud Control Panel**.
2. Go to **People → Add new user** (this creates a sub-account).
3. Set a username and password, and **enable "Allow API connections."**
   *(This toggle is required — without it Terraform gets `Forbidden`.)*
4. Put the credentials in your shell. Add these lines to `~/.zshrc` or
   `~/.bashrc` so they persist:

```bash
export UPCLOUD_USERNAME="the-api-subaccount"
export UPCLOUD_PASSWORD="its-password"
```

### Step 3 — Clone and configure (one-time)

```bash
git clone https://github.com/shaman1001/tak-deployment.git
cd tak-deployment
make configure     # creates terraform/terraform.tfvars from the template
make doctor        # checks tools + creds, and prints YOUR public IP
```

`make doctor` prints your current public IP — copy it. Now open
`terraform/terraform.tfvars` and set:

| Field             | What to put                                                            |
|-------------------|------------------------------------------------------------------------|
| `ssh_public_keys` | the contents of `~/.ssh/id_ed25519.pub`                                |
| `admin_ips`       | your public IP from `make doctor` (locks down SSH + the admin web UI)  |
| `zone` / `plan`   | defaults `fi-hel1` / `2xCPU-4GB` are fine to leave                      |
| `compose_ref`     | pin to a validated OpenTAKServer tag before a real op (see caveats)     |

### Step 4 — Launch the server

```bash
make init          # one-time per clone: downloads the UpCloud provider
make apply         # review the plan, type 'yes' — creates the server (~30s)
make output        # prints the IP, web UI URL, and ssh command
make bootstrap-log # optional: watch Docker + the stack install (~5-8 min)
```

The server is ready when `bootstrap-log` prints `stack up`, or when
`make status` lists running containers.

### Step 5 — Create users and hand out data packages

1. Open the web UI URL from `make output` (`https://<ip>`) from your admin
   machine. Accept the browser's self-signed-cert warning.
2. Log in with the OpenTAKServer default admin account and **change the password
   immediately.**
3. Create one user account per team member.
4. Download each user's **data package** (`.zip`) and send it to them. They
   import it into ATAK / iTAK / WinTAK — it carries the server's CA and their
   client cert, so the app connects with no further setup and no cert warning.

### Step 6 — Run the operation

```bash
make status   # containers running on the server
make logs     # tail the stack logs
make ssh      # shell into the server as takadmin
```

### Step 7 — End of operation (scorched earth)

```bash
make destroy  # type 'yes' — deletes the server and every byte of data
```

Next operation: start again at **Step 4**. A test run is just `make apply`
followed by `make destroy`; UpCloud bills by the hour, so it costs a few cents.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `terraform: command not found` | Step 1 not done, or restart your shell. `make doctor` confirms. |
| `ERROR: UPCLOUD_USERNAME not set` | Re-run the `export` lines from Step 2 in this shell. |
| `Failed to authenticate to UpCloud API` | Wrong creds, or the sub-account lacks **Allow API connections** (Step 2.3). |
| Can't reach `https://<ip>` / SSH times out | Your public IP changed. Update `admin_ips` in `terraform.tfvars` and re-run `make apply`. `make doctor` shows your current IP. |
| Web UI still down after ~8 min | `make ssh`, then `sudo tail -100 /var/log/tak-bootstrap.log`; `make status` for container states. |
| `Error: ... zone / plan / template ...` | That name isn't valid for your account — check exact values in the UpCloud Control Panel and update `terraform.tfvars`. |

All `make` targets: `make help`.

---

## How it fits together

```
terraform/   UpCloud server + platform firewall
  main.tf, variables.tf, outputs.tf, versions.tf, terraform.tfvars.example
cloud-init/  first-boot: install Docker, pull the PINNED compose stack, start it
  user-data.yaml.tftpl
Makefile     operator wrappers (configure/doctor/apply/destroy/ssh/logs/...)
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

- **Certificates are the server's job — and it does them.** OpenTAKServer
  auto-generates its own CA and issues each user's client certificate, bundled
  into the data package you hand out (CA truststore + client keystore +
  connection profile). ATAK/iTAK/WinTAK trust that CA straight from the package,
  so the field connection on 8089 has **no cert warning** — this is the intended
  TAK PKI model, not a gap. The only self-signed caveat is the **browser**: the
  web UI's own TLS cert is self-signed by default (a browser warning for the
  admin), and **QR-code enrollment requires a publicly trusted cert**. For
  either, add a domain, open port 80, and enable Let's Encrypt in the OTS config.
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
