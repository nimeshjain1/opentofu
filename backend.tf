terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.state_storage_account_name
    container_name       = var.state_container_name
    key                  = var.state_key
    use_azuread_auth     = true
  }
}