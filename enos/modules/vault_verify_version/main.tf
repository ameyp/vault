terraform {
  required_providers {
    enos = {
      source = "app.terraform.io/hashicorp-qti/enos"
    }
  }
}

variable "vault_install_dir" {
  type        = string
  description = "The directory where the Vault binary will be installed"
}

variable "vault_instance_count" {
  type        = number
  description = "How many vault instances are in the cluster"
}

variable "vault_instances" {
  type = map(object({
    private_ip = string
    public_ip  = string
  }))
  description = "The vault cluster instances that were created"
}

variable "vault_local_binary_path" {
  type        = string
  description = "The path to the local vault binary to compare version information"
}

variable "vault_root_token" {
  type        = string
  description = "The vault root token"
}

resource "enos_local_exec" "get_expected_version" {
  content = templatefile("${path.module}/templates/get-local-version.sh", {
    vault_local_binary_path = var.vault_local_binary_path
  })
}

locals {
  public_ips = {
    for idx in range(var.vault_instance_count) : idx => {
      public_ip  = values(var.vault_instances)[idx].public_ip
      private_ip = values(var.vault_instances)[idx].private_ip
    }
  }
}

resource "enos_remote_exec" "verify_all_nodes_have_updated_version" {
  for_each = local.public_ips

  content = templatefile("${path.module}/templates/verify-cluster-version.sh", {
    vault_install_dir = var.vault_install_dir,
    vault_token       = var.vault_root_token,
    expected_version  = trimspace(enos_local_exec.get_expected_version.stdout)
  })

  transport = {
    ssh = {
      host = each.value.public_ip
    }
  }
}
