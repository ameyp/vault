scenario "smoke" {
  matrix {
    arch           = ["amd64", "arm64"]
    backend        = ["consul", "raft"]
    builder        = ["local", "crt"]
    consul_version = ["1.12.3", "1.11.7", "1.10.12"]
    distro         = ["ubuntu", "rhel"]
    edition        = ["oss", "ent"]
    unseal_method  = ["awskms", "shamir"]
  }

  terraform_cli = terraform_cli.default
  terraform     = terraform.default
  providers = [
    provider.aws.default,
    provider.enos.ubuntu,
    provider.enos.rhel
  ]

  locals {
    bundle_path = abspath(var.vault_bundle_path)
    binary_path = abspath(var.vault_local_binary_path)
    dependencies_to_install = {
      "raft"   = ["jq"] // we need install jq for raft voter checking
      "consul" = []
    }
    enos_provider = {
      rhel   = provider.enos.rhel
      ubuntu = provider.enos.ubuntu
    }
    tags = merge({
      "Project Name" : var.project_name
      "Project" : "Enos",
      "Environment" : "ci"
    }, var.tags)
  }

  step "build_vault" {
    module = matrix.builder == "crt" ? module.build_crt : module.build_local

    variables {
      bundle_path               = local.bundle_path
      local_vault_artifact_path = local.binary_path
    }
  }

  step "find_azs" {
    module = module.az_finder

    variables {
      instance_type = [
        var.backend_instance_type,
        var.vault_instance_type
      ]
    }
  }

  step "create_vpc" {
    module = module.create_vpc

    variables {
      ami_architectures  = [matrix.arch]
      availability_zones = step.find_azs.availability_zones
      common_tags        = local.tags
    }
  }

  step "read_license" {
    skip_step = matrix.edition == "oss"
    module    = module.read_license

    variables {
      file_name = abspath(joinpath(path.root, "./support/vault.hclic"))
    }
  }

  step "create_backend_cluster" {
    module     = "backend_${matrix.backend}"
    depends_on = [step.create_vpc]

    providers = {
      enos = provider.enos.ubuntu
    }

    variables {
      ami_id      = step.create_vpc.ami_ids["ubuntu"][matrix.arch]
      common_tags = local.tags
      consul_release = {
        edition = var.backend_edition
        version = matrix.consul_version
      }
      instance_type = var.backend_instance_type
      kms_key_arn   = step.create_vpc.kms_key_arn
      vpc_id        = step.create_vpc.vpc_id
    }
  }

  step "create_vault_cluster" {
    module = module.vault_cluster
    depends_on = [
      step.create_vpc,
      step.create_backend_cluster,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      ami_id                    = step.create_vpc.ami_ids[matrix.distro][matrix.arch]
      common_tags               = local.tags
      consul_cluster_tag        = step.create_backend_cluster.consul_cluster_tag
      dependencies_to_install   = local.dependencies_to_install[matrix.backend]
      instance_count            = var.vault_instance_count
      instance_type             = var.vault_instance_type
      kms_key_arn               = step.create_vpc.kms_key_arn
      storage_backend           = matrix.backend
      unseal_method             = matrix.unseal_method
      vault_install_dir         = var.vault_install_dir
      vault_local_artifact_path = local.bundle_path
      vault_license             = matrix.edition != "oss" ? step.read_license.license : null
      vpc_id                    = step.create_vpc.vpc_id
    }
  }

  step "verify_raft_auto_join_voter" {
    skip_step = matrix.backend != "raft"
    module    = module.vault_verify_raft_auto_join_voter
    depends_on = [
      step.create_vault_cluster,
    ]

    providers = {
      enos = local.enos_provider[matrix.distro]
    }

    variables {
      vault_install_dir       = var.vault_install_dir
      vault_instance_count    = var.vault_instance_count
      vault_instances         = step.create_vault_cluster.vault_instances
      vault_local_binary_path = local.binary_path
      vault_root_token        = step.create_vault_cluster.vault_root_token
    }
  }

  output "vault_cluster_instance_ids" {
    description = "The Vault cluster instance IDs"
    value       = step.create_vault_cluster.instance_ids
  }

  output "vault_cluster_pub_ips" {
    description = "The Vault cluster public IPs"
    value       = step.create_vault_cluster.instance_public_ips
  }

  output "vault_cluster_priv_ips" {
    description = "The Vault cluster private IPs"
    value       = step.create_vault_cluster.instance_private_ips
  }

  output "vault_cluster_key_id" {
    description = "The Vault cluster Key ID"
    value       = step.create_vault_cluster.key_id
  }

  output "vault_cluster_root_token" {
    description = "The Vault cluster root token"
    value       = step.create_vault_cluster.vault_root_token
  }

  output "vault_cluster_unseal_keys_b64" {
    description = "The Vault cluster unseal keys"
    value       = step.create_vault_cluster.vault_unseal_keys_b64
  }

  output "vault_cluster_unseal_keys_hex" {
    description = "The Vault cluster unseal keys hex"
    value       = step.create_vault_cluster.vault_unseal_keys_hex
  }

  output "vault_cluster_tag" {
    description = "The Vault cluster tag"
    value       = step.create_vault_cluster.vault_cluster_tag
  }
}
