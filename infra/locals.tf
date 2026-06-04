locals {
  azure_env = module.sharedvariables.envs[var.environment].azure
  aws_env   = module.sharedvariables.envs[var.environment].aws

  github = {
    owner = module.sharedvariables.github.owner
    token = data.azurerm_key_vault_secret.github_access_token.value
  }
}