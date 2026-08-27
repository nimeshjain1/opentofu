# terraform {
#   required_version = ">= 1.9"

#   required_providers {
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 4.0"
#     }
#   }
# }

provider "azurerm" {
  features {}

  # Required in azurerm v4+. Alternatively export ARM_SUBSCRIPTION_ID.
  subscription_id = var.subscription_id
}

# ---------- Variables ----------

variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}


variable "state_storage_account_name" {
  description = "Storage account for remote state. Globally unique, 3-24 lowercase alphanumeric chars."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.state_storage_account_name))
    error_message = "Storage account names must be 3-24 characters, lowercase letters and numbers only."
  }
}

variable "state_container_name" {
  description = "Blob container holding the state file."
  type        = string
  default     = "tfstate"
}

variable "state_key" {
  description = "Blob name for this configuration's state file."
  type        = string
  default     = "demo-vm.tfstate"
}

variable "prefix" {
  description = "Name prefix for all resources."
  type        = string
  default     = "demo"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "VM SKU. B1s is the cheapest generally-available burstable size."
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Login name for the VM."
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key."
  type        = string
  # default     = "~/.ssh/id_rsa.pub"
  default = "id_rsa.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach port 22. Set this to your own IP/32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "resource_group_name" {
  description = "Name of the resource group to create."
  type        = string
  default     = "azurestorage"
}

# ---------- Resource group ----------

# resource "azurerm_resource_group" "main" {
 
#   location = var.location
# }

# ---------- Networking ----------

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "main" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ---------- Virtual machine ----------

resource "azurerm_linux_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.main.id]

  # Password auth is disabled by default; SSH key only.
  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# ---------- Outputs ----------

output "public_ip" {
  description = "Public IP address of the VM."
  value       = azurerm_public_ip.main.ip_address
}

output "ssh_command" {
  description = "Ready-to-paste SSH command."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.main.ip_address}"
}
