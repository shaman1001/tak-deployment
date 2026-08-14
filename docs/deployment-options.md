# TAK Server deployment — options and decision record

_Last researched: 2026-08-14._

This document explains why the previous setup kept breaking, the real options
for a **repeatable, turnkey** TAK deployment, and the choice this repo now
implements. If you want to change direction, this is the map.

---

## 1. Why the old approach was fragile

The repo had grown **three different, half-finished, mutually inconsistent
deployment attempts** (now preserved under `legacy/`):

| File (now in `legacy/`) | Approach | Problem |
|---|---|---|
| `gcp-infrastructure.sh` + `gcp-startup-ots.sh` | GCP instance template → `curl \| bash` a startup script that downloads the OpenTAKServer installer and **`sed`-patches it** (`s\|< /dev/tty\|\|g`, `apt install` → `apt install -y`) then pipes `yes "n"` into it | Any upstream change to the installer breaks the `sed` substitutions. curl-pipe-bash off a mutable branch is not reproducible. |
| `ots-installer-lazydog.sh` | A *second* GCP + OTS attempt using a different installer, patched with `printf 'y\nn\nn\ny\n'` | Fragile in the same way, plus a real bug: `curl ... -o installer.sh chmod +x ...` runs `chmod` as an argument to `curl`, so it never executes. Uses different credentials than the other script. |
| `notes-cloudrf-docker.md` | Manual notes for a *third* approach — official TAK Server via Cloud-RF Docker | Never automated; manual `git clone`, manual ZIP upload, interactive `./setup.sh`. |

**The common root cause: every attempt tries to drive an _interactive_
installer non-interactively by rewriting its text at boot.** That is inherently
brittle. On top of that: imperative cloud-specific `gcloud` commands, no pinned
versions, `ufw disable` (opens the box wide), and inconsistent conventions.

The fix is not "patch the installer better." It is to **stop patching
installers** and instead run pre-built, non-interactive container images from
version-controlled config, on declaratively-provisioned infrastructure.

---

## 2. Which TAK server to run

There are three realistic implementations. They are not interchangeable — they
differ in auth model, features, and how automatable they are.

### OpenTAKServer (OTS) — **chosen default**
- Python/Flask reimplementation with a **web UI**, REST API, the **CloudTAK**
  browser client, automatic certificate authority + client-cert enrollment.
- **Username/password web login + downloadable data packages** — this is
  exactly the workflow the old `README.md` described ("log in, create users,
  download the `.zip`, send to the team"). No change to how operators work.
- Ships as **docker compose** (multi-container: OTS, Postgres/PostGIS,
  RabbitMQ, nginx, optional MediaMTX). Non-interactive `docker compose up -d`.
- Trade-off: the Docker packaging is young and upstream flags it as not yet
  production-hardened. **Pin to a validated ref** and test once before an op.

### Official TAK Server (GOTS) via Cloud-RF Docker
- The "real" Java TAK Server from tak.gov, wrapped in Docker by Cloud-RF.
- Production-grade and the most feature-complete / compliance-friendly.
- Trade-offs for turnkey use:
  - Requires downloading the gated `TAKSERVER-DOCKER-x.x-RELEASE.zip` from
    tak.gov (registration/approval) — can't be fetched unattended.
  - `setup.sh` is **interactive** (prompts for cert names, network interface),
    so it needs automation work to be turnkey.
  - **Client-certificate auth** (`admin.p12`, `atakatak`) — more secure but a
    heavier per-user workflow than OTS's username/password + data packages.
- Pick this if you need the official server for compliance or feature parity.

### FreeTAKServer (FTS)
- Lighter Python server, easy to start, but a **more limited feature set** (no
  broad REST API surface, no browser client) and less active. Not recommended
  unless you specifically want minimalism.

**Decision:** OpenTAKServer. It matches the existing operator workflow, is fully
container-based (so it can be made genuinely turnkey), and keeps the
username/password + data-package model the team already knows.

---

## 3. How to deploy it (the part that actually fixes "turnkey")

Regardless of which server you pick, the deployment method is what makes it
repeatable:

1. **Docker Compose, not installer scripts.** Container images are already
   non-interactive and version-pinned. No `sed`, no `yes "n"`, no TTY hacks.
2. **Declarative infrastructure (Terraform), not imperative `gcloud`.** One
   `apply` builds it, one `destroy` wipes it — which preserves the "scorched
   earth" ephemeral model the old README wanted, but reliably.
3. **cloud-init for first boot, not `curl | bash`.** cloud-init installs Docker
   and starts the pinned stack. It's the platform's native, ordered bootstrap.
4. **Pin everything.** Provider version, OS template, and the compose ref.

This repo implements exactly that: `terraform/` (infra) + `cloud-init/`
(bootstrap) + `Makefile` (operator commands).

---

## 4. Infrastructure options on UpCloud

UpCloud is a good fit: Finnish provider, **Helsinki zones `fi-hel1` / `fi-hel2`**
for low latency (the same reason the old setup chose GCP Hamina), a first-class
**Terraform provider** (`UpCloudLtd/upcloud`), cloud-init support, and a
platform firewall.

Three ways to run it, in order of how this repo uses them:

- **A. Terraform + cloud-init (install on boot) — implemented here.** Fully
  declarative and reproducible from scratch. First boot takes ~5–8 min. Best
  "infrastructure as code" story. `make apply` / `make destroy`.
- **B. Golden image / snapshot (build once, boot many).** Do a Terraform build
  once, snapshot the disk, then boot each operation from the snapshot in ~2 min
  with zero install risk. This is the strongest **operational** model for
  frequent ephemeral ops and mirrors what the old GCP "instance template" was
  reaching for. Easy to add on top of A later.
- **C. `upctl` CLI + cloud-init (no Terraform state).** Lighter, scriptable, no
  state file — but you lose the declarative graph and clean teardown. Fine for
  one-offs.

The Docker layer is portable, so **only the `terraform/` directory is
UpCloud-specific** — the same compose stack runs on any provider (or on-prem) if
you ever need to move.

---

## 5. Switching implementations

The server implementation is a Terraform variable, not a hardcoded choice:

- **OTS, build-from-source (default):**
  `compose_repo = "https://github.com/brian7704/OpenTAKServer-Docker.git"`
- **OTS, prebuilt images (faster boot, community-maintained):**
  `compose_repo = "https://github.com/milsimdk/ots-docker.git"`
- **Official TAK Server:** use the Cloud-RF stack — but note it needs the gated
  tak.gov ZIP and its `setup.sh` must be made non-interactive first, so it isn't
  a drop-in `compose_ref` change yet.

Always set `compose_ref` to a **specific tag or commit** you have validated.

---

## Sources

- [OpenTAKServer](https://github.com/brian7704/OpenTAKServer) · [OpenTAKServer-Docker](https://github.com/brian7704/OpenTAKServer-Docker) · [docs](https://docs.opentakserver.io/)
- [milsimdk/ots-docker](https://github.com/milsimdk/ots-docker) (prebuilt-image compose)
- [Cloud-RF/tak-server](https://github.com/Cloud-RF/tak-server) (official TAK Server in Docker)
- [FreeTAKServer](https://github.com/FreeTAKTeam/FreeTakServer) · [feature comparison](https://docs.opentakserver.io/feature_comparison.html)
- [UpCloud Terraform provider](https://github.com/UpCloudLtd/terraform-provider-upcloud) · [cloud-init UpCloud datasource](https://docs.cloud-init.io/en/stable/reference/datasources/upcloud.html)
