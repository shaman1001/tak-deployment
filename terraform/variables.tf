# -----------------------------------------------------------------------------
# Infrastructure shape
# -----------------------------------------------------------------------------

variable "hostname" {
  description = "Server hostname (also used as the UpCloud server title)."
  type        = string
  default     = "tak-op"
}

variable "zone" {
  description = <<-EOT
    UpCloud zone. fi-hel1 / fi-hel2 are Helsinki, Finland (lowest latency for a
    Finnish operation, same reason the old GCP setup used europe-north1/Hamina).
    Run `upctl zone list` to see all zones.
  EOT
  type        = string
  default     = "fi-hel1"
}

variable "plan" {
  description = <<-EOT
    UpCloud server plan. OpenTAKServer's full docker stack (Postgres/PostGIS,
    RabbitMQ, nginx, media) wants >= 4 GB RAM. "2xCPU-4GB" is a sensible start;
    step up to "4xCPU-8GB" for larger teams. Run `upctl plan list`.
  EOT
  type        = string
  default     = "2xCPU-4GB"
}

variable "disk_size" {
  description = "OS disk size in GB."
  type        = number
  default     = 40
}

variable "os_template" {
  description = <<-EOT
    Public OS template title (or UUID). Must be a cloud-init capable template.
    Run `upctl storage list --template` for exact titles in your account.
  EOT
  type        = string
  default     = "Ubuntu Server 24.04 LTS (Noble Numbat)"
}

# -----------------------------------------------------------------------------
# Access control
# -----------------------------------------------------------------------------

variable "ssh_public_keys" {
  description = "SSH public keys allowed to log in as the 'takadmin' user."
  type        = list(string)
}

variable "admin_ips" {
  description = <<-EOT
    Individual public IPv4 addresses allowed to reach SSH (port 22), e.g.
    ["203.0.113.10"]. Lock this to your own address(es); do NOT leave SSH open
    to the internet. The client-facing TAK ports are opened to everyone
    separately (see main.tf) because field devices connect from arbitrary
    networks. Each entry becomes one accept rule (source start == end).
  EOT
  type        = list(string)
  # No default on purpose — you must set this so SSH isn't left wide open.
}

# -----------------------------------------------------------------------------
# Application (OpenTAKServer via docker compose)
# -----------------------------------------------------------------------------

variable "compose_repo" {
  description = <<-EOT
    Git repo containing the docker compose stack the server should run.
    Default is the upstream OpenTAKServer docker repo. See docs/deployment-options.md
    for alternatives (milsimdk prebuilt images, or Cloud-RF official TAK Server).
  EOT
  type        = string
  default     = "https://github.com/brian7704/OpenTAKServer-Docker.git"
}

variable "compose_ref" {
  description = <<-EOT
    Git ref (tag/branch/commit) to check out from compose_repo. PIN THIS to a
    tag or commit you have validated once — never deploy an operation off a
    moving 'master'. Set it in terraform.tfvars.
  EOT
  type        = string
  default     = "master"
}
