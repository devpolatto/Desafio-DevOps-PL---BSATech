module "sharedvariables" {
  source = "git::ssh://git@ssh.dev.azure.com/v3/polattoxcodelearning/Lab/TerraformModules//shared-variables?ref=main"
}

data "azurerm_key_vault" "kv" {
  name                = local.azure_env.keyvault.default.name
  resource_group_name = local.azure_env.keyvault.default.resource_group_name
}

data "azurerm_key_vault_secret" "github_access_token" {
  name         = local.azure_env.secrets.github_access_token
  key_vault_id = data.azurerm_key_vault.kv.id
}

data "github_repository" "Desafio_DevOps" {
  full_name = "devpolatto/Desafio-DevOps-PL---BSATech"
}