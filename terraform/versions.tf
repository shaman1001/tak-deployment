terraform {
  required_version = ">= 1.5"

  required_providers {
    upcloud = {
      source = "UpCloudLtd/upcloud"
      # Pinned to the current 5.x line (latest at time of writing: 5.43.0).
      # `terraform init` writes .terraform.lock.hcl; commit it if you want
      # byte-for-byte reproducible provider versions across machines.
      version = "~> 5.43"
    }
  }
}
