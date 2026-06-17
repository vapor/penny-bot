# Penny Bot — Terraform

Terraform project for Penny bot's infrastructure.

## Usage

Example usage; see Requirements section below:

```bash
# install tools via mise; requires mise installed
mise install
# login via aws CLI; requires aws CLI installed and configured with a `vapor` profile
aws login --profile vapor
# run lint if needed; requires terraform and tflint installed
./scripts/tf-check.bash

# work with terraform
cd ./terraform
# activate mise so you don't need to prefix all the following terraform commands with `mise x --`
mise activate fish | source   # bash: eval "$(mise activate bash)" — puts the pinned tools on PATH
terraform init
terraform plan
terraform apply
```

## Requirements

- **AWS CLI v2** ([install](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)) with a `vapor` profile resolving to account `177420307256` in `eu-west-1`.
  - Example `~/.aws/config` (see [configuring profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)):

    ```ini
    [profile vapor]
    account_id = 177420307256
    region = eu-west-1
    login_session = arn:aws:iam::177420307256:user/mahdi
    ```

    Then sign in to the profile (e.g. `aws login --profile vapor`); see the [AWS CLI authentication guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html) for the available sign-in options.

- **[mise](https://mise.jdx.dev)** ([install](https://mise.jdx.dev/installing-mise.html)) — provides the pinned tools declared in `.mise.toml`. Run `mise install`, then [activate mise](https://mise.jdx.dev/installing-mise.html#shells) in your shell so the pinned tools are on your PATH (or prefix individual commands with `mise x --`).
- **Terraform 1.15.6** (also enforced by `required_version`) and **TFLint 0.61.0** — pinned in `.mise.toml`, installed via mise (above).

## First run

At first run, you'll need to run the bootstrap terraform to create the state S3 bucket:

```bash
# activate mise so you don't need to prefix all the following terraform commands with `mise x --`
mise activate fish | source   # bash: eval "$(mise activate bash)" — puts the pinned tools on PATH
cd ./terraform/bootstrap && terraform init && terraform apply
cd .. && terraform init && terraform plan
terraform apply
```

Also ECR and Lambda deployments might fail since there can be cyclic dependencies between e.g. an ECR image / Lambda executable zip file existing and the ECS/lambda resources being created.

## Container image tag

`var.penny_image_tag` selects the ECS image tag.
When unset, it defaults to the tag of the **currently deployed** task definition (read live via a data source), so local `terraform plan` stays zero-diff with no hardcoded value. CI passes the freshly built tag explicitly (`-var penny_image_tag=<git-sha>`).
On a **fresh account** there is no live task definition to read, so you must supply it on the first apply: `TF_VAR_penny_image_tag=<tag> terraform apply`.

Not in code (needed to replicate elsewhere):

- Secret values for all 8 `prod/penny/penny-bot/*` secrets.
- `penny-bot-deployer` access-key secret (If needed, a recreation is required.).
- Shared org resources used as data sources: default VPC, OIDC provider, `GithubOIdP-Role` (`repo:vapor/*`).
