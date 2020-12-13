
#######################################################################
## Create Virtual Network
#######################################################################

resource "azurerm_virtual_network" "onprem-vnet" {
  name                = "onprem-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.privatelink-dns-microhack-rg.name
  address_space       = ["192.168.0.0/16"]
  dns_servers         = ["192.168.0.4"]

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Subnets
#######################################################################
resource "azurerm_subnet" "onprem-infrastructure-subnet" {
  name                 = "InfrastructureSubnet"
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name = azurerm_virtual_network.onprem-vnet.name
  address_prefix       = "192.168.0.0/24"
}


#######################################################################
## Create Network Interfaces
#######################################################################

resource "azurerm_network_interface" "onprem-dns-nic" {
  name                 = "onprem-dns-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  
  ip_configuration {
    name                          = "onprem-dns-nic"
    subnet_id                     = azurerm_subnet.onprem-infrastructure-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "192.168.0.4"
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_network_interface" "onprem-mgmt-nic" {
  name                 = "onprem-mgmt-nic"
  location             = var.location
  resource_group_name  = azurerm_resource_group.privatelink-dns-microhack-rg.name
  
  ip_configuration {
    name                          = "onprem-mgmt-nic"
    subnet_id                     = azurerm_subnet.onprem-infrastructure-subnet.id
    private_ip_address_allocation = "static"
    private_ip_address            = "192.168.0.5"
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

#######################################################################
## Create Network Peering
#######################################################################

resource "azurerm_virtual_network_peering" "onprem-hub-peer" {
  name                      = "onprem-hub-peer"
  resource_group_name       = azurerm_resource_group.privatelink-dns-microhack-rg.name
  virtual_network_name      = azurerm_virtual_network.onprem-vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub-vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
  depends_on                   = [azurerm_virtual_network.onprem-vnet, azurerm_virtual_network.hub-vnet]
}

#######################################################################
## Create Virtual Machines
#######################################################################

resource "azurerm_virtual_machine" "onprem-dns-vm" {
  name                  = "onprem-dns-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.privatelink-dns-microhack-rg.name
  network_interface_ids = [azurerm_network_interface.onprem-dns-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "onprem-dns-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "onprem-dns-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}

resource "azurerm_virtual_machine" "onprem-mgmt-vm" {
  name                  = "onprem-mgmt-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.privatelink-dns-microhack-rg.name
  network_interface_ids = [azurerm_network_interface.onprem-mgmt-nic.id]
  vm_size               = var.vmsize

  storage_image_reference {
    offer     = "WindowsServer"
    publisher = "MicrosoftWindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "onprem-mgmt-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "onprem-mgmt-vm"
    admin_username = var.username
    admin_password = var.password
  }

  os_profile_windows_config {
    provision_vm_agent = true
  }

  tags = {
    environment = "onprem"
    deployment  = "terraform"
    microhack   = "privatelink-dns"
  }
}
