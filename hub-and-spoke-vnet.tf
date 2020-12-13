#######################################################################
## Create Virtual Networks
#######################################################################

resource "azurerm_virtual_network" "hub-vnet" {
  name                = "hub-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_virtual_network" "spoke-vnet" {
  name                = "spoke-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  address_space       = ["10.1.0.0/16"]

  tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Subnets
#######################################################################

resource "azurerm_subnet" "hub-bastion-subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefix       = "10.0.1.0/27"
}

resource "azurerm_subnet" "hub-dns" {
  name                 = "DNSSubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.hub-vnet.name
  address_prefix       = "10.0.0.0/24"
}

resource "azurerm_subnet" "spoke-infrastructure" {
  name                 = "InfrastructureSubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.spoke-vnet.name
  address_prefix       = "10.1.0.0/24"
}

#######################################################################
## Create Public IPs
#######################################################################

resource "azurerm_public_ip" "hub-bastion-pip" {
  name                = "hub-bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "hub"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}


#######################################################################
## Create Bastion Services
#######################################################################

resource "azurerm_bastion_host" "hub-bastion-host" {
  name                = "hub-bastion-host"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name

  ip_configuration {
    name                 = "hub-bastion-host"
    subnet_id            = azurerm_subnet.hub-bastion-subnet.id
    public_ip_address_id = azurerm_public_ip.hub-bastion-pip.id
  }

  tags = {
    environment = "hub"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Network Peering
#######################################################################

resource "azurerm_virtual_network_peering" "hub-spoke-peer" {
  name                         = "hub-spoke-peer"
  resource_group_name          = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name         = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  depends_on                   = [azurerm_virtual_network.spoke-vnet, azurerm_virtual_network.hub-vnet]
}

resource "azurerm_virtual_network_peering" "spoke-hub-peer" {
  name                      = "spoke-hub-peer"
  resource_group_name       = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name      = azurerm_virtual_network.spoke-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  depends_on                   = [azurerm_virtual_network.spoke-vnet, azurerm_virtual_network.hub-vnet]
}

resource "azurerm_virtual_network_peering" "hub-onprem-peer" {
  name                      = "hub-onprem-peer"
  resource_group_name       = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name      = azurerm_virtual_network.hub-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.onprem-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  depends_on                   = [azurerm_virtual_network.onprem-vnet, azurerm_virtual_network.hub-vnet]
}

#######################################################################
## Create Network Interface
#######################################################################

resource "azurerm_network_interface" "az-dns-nic" {
  name                 = "az-dns-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "az-dns-nic"
    subnet_id                     = azurerm_subnet.hub-dns.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_network_interface" "az-mgmt-nic" {
  name                 = "az-mgmt-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "az-mgmt-nic"
    subnet_id                     = azurerm_subnet.spoke-infrastructure.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Virtual Machine
#######################################################################

resource "azurerm_virtual_machine" "az-dns-vm" {
  name                  = "az-dns-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.privatelink-dns-microhack-rg.name
  network_interface_ids = [azurerm_network_interface.az-dns-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "az-dns-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "az-dns-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "hub-spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_virtual_machine" "az-mgmt-vm" {
  name                  = "az-mgmt-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.privatelink-dns-microhack-rg.name
  network_interface_ids = [azurerm_network_interface.az-mgmt-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "az-mgmt-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "az-mgmt-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "spoke"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}
