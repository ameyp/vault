# Enos

Enos is an quality testing framework that allows composing and executing quality
requirement scenarios as code. For Vault, it is currently used to perform
infrastructure integration testing using the artifacts that are created as part
of the `build` workflow. While intended to be executed via Github Actions using
the results of the `build` workflow, scenarios are also executable from a developer
machine that has the requisite dependencies and configuration.

Refer to the [Enos documentation](https://github.com/hashicorp/Enos-Docs)
for further information regarding installation, execution or composing Enos scenarios.

## Requirements
* AWS access. HashiCorp Vault developers should use Doormat.
* Terraform >= 1.2
* Enos >= v0.0.10. You can [install it from a release channel](https://github.com/hashicorp/Enos-Docs/blob/main/installation.md).
* Access to the QTI org in Terraform Cloud. HashiCorp Vault developers can
  access a shared token in 1Password or request their own in #team-quality on
  Slack.
* An SSH keypair in the AWS region you wish to run the scenario. You can use
  Doormat to log in to the AWS console to create or upload an existing keypair.
* A Vault install bundle downloaded from releases.hashicorp.com or Artifactory
  when using the `builder:crt` variants. When using the `builder:local` variants
  Enos will build a Vault bundle from the current branch for you.

## Scenario Variables
In CI, each scenario is executed via Github Actions and has been configured using
environment variable inputs that follow the `ENOS_VAR_varname` pattern.

For local execution you can specify all the required variables using environment
variables, or you can update `enos.vars.hcl` with values and uncomment the lines.

Variables that are required:
- `aws_ssh_keypair_name`
- `aws_ssh_private_key_path`
- `tfc_api_token`
- `vault_bundle_path`
- `vault_license_path` (only required for non-OSS editions)

See [enos.vars.hcl](./enos.vars.hcl) or [enos-variables.hcl](./enos-variables.hcl)
for further descriptions of the variables.

## Executing Scenarios
From the `enos` directory:

```bash
# List all available scenarios
enos scenario list
# Run the smoke or upgrade scenario with an artifact that is built locally. Make sure
# the local machine has been configured as detailed in the requirements
# section. This will execute the scenario and clean up any resources if successful.
enos scenario run smoke builder:local
enos scenario run upgrade builder:local
# To run the same scenario variants that are run in CI, refer to the scenarios listed
# in .github/workflows/enos-run.yml under `jobs.enos.strategy.matrix.include`,
# adding `builder:local` to run locally.
enos scenario run smoke backend:consul consul_version:1.12.3 distro:ubuntu unseal_method:awskms builder:local
# Launch an individual scenario but leave infrastructure up after execution
enos scenario launch smoke builder:local
# Check an individual scenario for validity. This is useful during scenario
# authoring and debugging.
enos scenario validate smoke builder:local
# If you've run the tests and desire to see the outputs, such as the URL or
# credentials, you can run the output command to see them. Please note that
# after "run" or destroy there will be no "outputs" as the infrastructure
# will have been destroyed and state cleared.
enos scenario output smoke builder:local
# Explicitly destroy all existing infrastructure
enos scenario destroy smoke builder:local
```

Refer to the [Enos documentation](https://github.com/hashicorp/Enos-Docs)
for further information regarding installation, execution or composing scenarios.

# Scenarios

There are current two scenarios: `smoke` and `upgrade`. Both begin by building Vault
as specified by the selected `builder` variant (see Variants section below for more
information).

## Smoke

The [`smoke` scenario](./enos-scenario-smoke.hcl) creates a Vault cluster using
the version from the current branch (either in CI or locally), with the backend
specified by the `backend` variant (`raft` or `consul`). Next, it unseals with the
appropriate method (`awskms` or `shamir`).
## Upgrade

The [`upgrade` scenario](./enos-scenario-upgrade.hcl) creates a Vault cluster using
the version specified in `vault_upgrade_initial_release`, with the backend specified
by the `backend` variant (`raft` or `consul`). Next, it upgrades the Vault binary
that is determined by the `builder` variant. After the upgrade, it verifies the
Vault version.

# Variants

Both scenarios support a matrix of variants. In order to achieve broad coverage while
keeping test run time reasonable, the variants executed by the `enos-run` Github
Actions are tailored to maximize variant distribution per scenario.

## `builder:crt`

This variant is designed for use in Github Actions. The `enos-run.yml` workflow
downloads the artifact built by the `build.yml` workflow, unzips it, and sets the
`vault_bundle_path` to the zip file and the `vault_local_binary_path` to the binary.

## `builder:local`

This variant is for running the Enos scenario locally. It builds the Vault bundle
from the current branch, placing the bundle at the `vault_bundle_path` and the
unzipped Vault binary at the `vault_local_binary_path`.
