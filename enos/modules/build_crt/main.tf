# Shim module since CRT provided things will use the crt_bundle_path variable
variable "bundle_path" {
  default = "/tmp/vault.zip"
}

variable "local_vault_artifact_path" {
  default = "/tmp/vault"
}
