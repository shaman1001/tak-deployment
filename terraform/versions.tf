terraform {
  required_version = ">= 1.5"

  required_providers {
    upcloud = {
      source = "UpCloudLtd/upcloud"
      # Pin the provider so `terraform apply` is reproducible over time.
      # Check https://github.com/UpCloudLtd/terraform-provider-upcloud/releases
      # for the current line and bump deliberately.
      version = "~> 5.0"
    }
  }
}
