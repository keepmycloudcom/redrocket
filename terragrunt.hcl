### Terraform configuration
terraform {
  extra_arguments "custom_vars" {
    commands = get_terraform_commands_that_need_vars()

    required_var_files = [
      "${get_parent_terragrunt_dir()}/common.tfvars",
    ]

    # Ensure that terraform.tfvars is loaded *after* common.tfvars
    optional_var_files = [
      "${get_terragrunt_dir()}/terraform.tfvars",
    ]
  }
}

# vim:filetype=terraform ts=2 sw=2 et:
