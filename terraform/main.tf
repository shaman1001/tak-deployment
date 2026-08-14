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

  # TAK client ports opened to the whole internet. Field devices (ATAK/iTAK/
  # WinTAK) connect from arbitrary networks, so these cannot be IP-restricted.
  #   8089 : CoT streaming over TLS   — the core client connection
  #   8443 : TAK API / data sync / data-package download over TLS
  #   8446 : certificate enrollment   — drop this if you hand out certs only
  #          via data packages (then clients never enroll directly)
  # NOT opened by default (open in the firewall below only if you need them):
  #   80   : Let's Encrypt http-01 challenge (only if using a real cert)
  #   8080 : internal API (nginx proxies it on 443, no external need)
  #   8883 : MQTT/TLS (only for Meshtastic / MQTT integrations)
  client_tcp_ports = [8089, 8443, 8446]

  any_ipv4_start = "0.0.0.0"
  any_ipv4_end   = "255.255.255.255"
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

  # === ADMIN PLANE: restricted to your own IP(s) ==============================

  # SSH (22)
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
      comment                = "SSH from admin ${firewall_rule.value}"
    }
  }

  # Web admin UI / CloudTAK (443) — admin only by default. This keeps the
  # OpenTAKServer login page (which starts with default credentials) off the
  # public internet until you've changed the password.
  dynamic "firewall_rule" {
    for_each = var.admin_ips
    content {
      action                 = "accept"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_start   = firewall_rule.value
      source_address_end     = firewall_rule.value
      destination_port_start = "443"
      destination_port_end   = "443"
      comment                = "Web UI from admin ${firewall_rule.value}"
    }
  }

  # ICMP echo (ping) — admin only
  dynamic "firewall_rule" {
    for_each = var.admin_ips
    content {
      action               = "accept"
      direction            = "in"
      family               = "IPv4"
      protocol             = "icmp"
      source_address_start = firewall_rule.value
      source_address_end   = firewall_rule.value
      icmp_type            = "8"
      comment              = "ICMP echo from admin ${firewall_rule.value}"
    }
  }

  # === CLIENT PLANE: open to the internet (field devices connect from anywhere) ==
  dynamic "firewall_rule" {
    for_each = local.client_tcp_ports
    content {
      action                 = "accept"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_start   = local.any_ipv4_start
      source_address_end     = local.any_ipv4_end
      destination_port_start = tostring(firewall_rule.value)
      destination_port_end   = tostring(firewall_rule.value)
      comment                = "TAK client port ${firewall_rule.value}"
    }
  }

  # Optionally expose the web UI / CloudTAK browser client to everyone. Only
  # enable this if field users use the browser client — and change the default
  # OpenTAKServer password BEFORE you do, since the login page becomes public.
  dynamic "firewall_rule" {
    for_each = var.open_web_ui_to_world ? [1] : []
    content {
      action                 = "accept"
      direction              = "in"
      family                 = "IPv4"
      protocol               = "tcp"
      source_address_start   = local.any_ipv4_start
      source_address_end     = local.any_ipv4_end
      destination_port_start = "443"
      destination_port_end   = "443"
      comment                = "Web UI open to world"
    }
  }

  # === Default deny for everything else inbound (IPv4 + IPv6) ==================
  # UpCloud's firewall is stateful, so replies to connections the server itself
  # opens (Docker/GitHub pulls, apt, NTP, DNS) are allowed without an out rule.
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
