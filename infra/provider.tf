terraform {

  backend "azurerm" {
    key              = "Desafio-DevOps-PL-BSATech"
    use_azuread_auth = true
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.59.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.7.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.11"
    }
    docker = {
      source  = "docker/docker"
      version = "~> 0.2"
    }
  }
}

provider "azurerm" {
  subscription_id = local.azure_env.account.subscription
  features {}
}

provider "azuread" {
}

provider "github" {
  token = local.github.token
  owner = local.github.owner
}

provider "docker" {}