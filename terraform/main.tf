# =============================================================================
# TAK server on UpCloud — one `terraform apply` to stand up, `destroy` to wipe.
#
# Credentials come from the environment (never commit them):
#   export UPCLOUD_USERNAME="<api-subaccount>"
#   export UPCLOUD_PASSWORD="<api-subaccount-password>"
# Create a dedicated API-enabled sub-account in the UpCloud control panel under
# People; do not use your main login.
# =============================================================================

provider "upcloud" {
  # Reads UPCLOUD_USERNAME / UPCLOUD_PASSWORD from the environment.
}

# First-boot bootstrap: install Docker, pull the pinned compose stack, start it.
locals {
  user_data = templatefile("${path.module}/../cloud-init/user-data.yaml.tftpl", {
    compose_repo = var.compose_repo
    compose_ref  = var.compose_ref
  })

  # Client-facing ports opened to the whole internet. Field devices (ATAK/iTAK/
  # WinTAK) and the browser client connect from arbitrary networks, so these
  # cannot be IP-restricted the way SSH is. See docs/deployment-options.md.
  #   443  : web UI / CloudTAK browser client (and certbot http-01 on 80)
  #   8443 : TAK API / data over TLS
  #   8446 : certificate enrollment
  #   8089 : CoT streaming over TLS (the main client connection)
  #   8883 : MQTT over TLS
  public_tcp_ports = [80, 443, 8443, 8446, 8089, 8883]
}

resource "upcloud_server" "tak" {
  hostname = var.hostname
  zone     = var.zone
  plan     = var.plan
  metadata = true # required for cloud-init based templates
  firewall = true # enable the platform firewall (rules below)

  template {
    storage = var.os_template
    size    = var.disk_size
  }

  network_interface {
    type = "public"
  }

  login {
    user            = "takadmin"
    keys            = var.ssh_public_keys
    create_password = false
  }

  user_data = local.user_data
}

# Note on a stable public IP across operations: UpCloud floating IPs also need
# in-OS interface configuration to receive traffic, so they aren't a pure
# Terraform toggle. For a stable address, use the golden-image/snapshot model
# (see docs/deployment-options.md, option B) instead.

resource "upcloud_firewall_rules" "tak" {
  server_id = upcloud_server.tak.id

  # --- SSH: only from known admin IPs -----------------------------------------
  dynamic "firewall_rule" {
    for_each = var.admin_ips
    content {
      action                 = "accept"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_start   = firewall_rule.value
      source_address_end     = firewall_rule.value
      destination_port_start = "22"
      destination_port_end   = "22"
      comment                = "SSH from admin"
    }
  }

  # --- TAK client / web ports: open to the internet ---------------------------
  dynamic "firewall_rule" {
    for_each = local.public_tcp_ports
    content {
      action                 = "accept"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      destination_port_start = tostring(firewall_rule.value)
      destination_port_end   = tostring(firewall_rule.value)
      comment                = "TAK/web port ${firewall_rule.value}"
    }
  }

  # --- Allow established/related return traffic and ICMP echo ------------------
  firewall_rule {
    action    = "accept"
    direction = "in"
    family    = "IPv4"
    protocol  = "icmp"
    icmp_type = "8" # echo request (ping)
    comment   = "ICMP echo"
  }

  # --- Default deny for everything else inbound (IPv4 + IPv6) ------------------
  firewall_rule {
    action    = "drop"
    direction = "in"
    family    = "IPv4"
    comment   = "Default deny IPv4 in"
  }
  firewall_rule {
    action    = "drop"
    direction = "in"
    family    = "IPv6"
    comment   = "Default deny IPv6 in"
  }
}
