locals {
  public_ip = one([
    for iface in upcloud_server.tak.network_interface : iface.ip_address
    if iface.type == "public" && iface.ip_address != ""
  ])
}

output "server_ip" {
  description = "Public IPv4 address to hand to the team / open in a browser."
  value       = local.public_ip
}

output "web_ui" {
  description = "OpenTAKServer web UI / CloudTAK browser client."
  value       = "https://${local.public_ip}"
}

output "ssh" {
  description = "SSH command (from an allowed admin IP)."
  value       = "ssh takadmin@${local.public_ip}"
}

output "next_steps" {
  description = "What to do after apply."
  value       = <<-EOT
    1. Wait ~5-8 min for cloud-init to install Docker and start the stack.
       Watch progress: ssh takadmin@${local.public_ip} 'sudo tail -f /var/log/tak-bootstrap.log'
    2. Open https://${local.public_ip} and accept the self-signed cert.
    3. Log in with the OpenTAKServer default admin account and CHANGE THE
       PASSWORD immediately.
    4. Create user accounts, download their data packages, distribute to the team.
    5. End of operation: `make destroy` wipes everything.
  EOT
}
