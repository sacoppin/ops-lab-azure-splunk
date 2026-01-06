terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

# 1. DATA (Ton Resource Group)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

# 2. RESEAU
resource "azurerm_virtual_network" "vnet" {
  name                = "lab-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 3. SECURITÉ (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "lab-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowAll"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "80", "8000", "8089", "9997"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 4. IPs PUBLIQUES
resource "azurerm_public_ip" "splunk_pip" {
  name                = "splunk-pip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "app_pip" {
  name                = "app-pip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 5. INTERFACES RÉSEAU (NICs)
resource "azurerm_network_interface" "splunk_nic" {
  name                = "splunk-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.splunk_pip.id
  }
}

resource "azurerm_network_interface" "app_nic" {
  name                = "app-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.app_pip.id
  }
}

# --- C'EST ICI LE CORRECTIF (ASSOCIATIONS) ---
# On attache le pare-feu aux cartes réseaux pour que le port 22 s'ouvre !

resource "azurerm_network_interface_security_group_association" "splunk_assoc" {
  network_interface_id      = azurerm_network_interface.splunk_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_network_interface_security_group_association" "app_assoc" {
  network_interface_id      = azurerm_network_interface.app_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
# ---------------------------------------------

# 6. VMs
resource "azurerm_linux_virtual_machine" "splunk_vm" {
  name                = "splunk-server"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.splunk_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "app-server"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.app_nic.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.ssh_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Outputs
output "splunk_public_ip" { value = azurerm_linux_virtual_machine.splunk_vm.public_ip_address }
output "splunk_private_ip" { value = azurerm_linux_virtual_machine.splunk_vm.private_ip_address }
output "app_public_ip" { value = azurerm_linux_virtual_machine.app_vm.public_ip_address }