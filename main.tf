terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-state-projeto"
    storage_account_name = "remotestateprojeto"
    container_name       = "tfstate-projeto"
    key                  = "prod/azure/vnet-modulo/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}

  # azurerm 4.x exige a subscription explicitamente.
  # Definida via env var: export ARM_SUBSCRIPTION_ID="<id da subscription>"
  # (obtenha com: az account show --query id -o tsv)
}