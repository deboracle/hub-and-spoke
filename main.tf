# hub and spoke exercise terraform answers - deborah gironde

# provider configuration
provider "azurerm" {
  features {}
}

# create resource group for the hub
resource "azurerm_resource_group" "deborah_hub_rg" {
  name     = "deborah-hub-rg"
  location = "West US"
}

# create resource group for the work spoke
resource "azurerm_resource_group" "deborah_work_spoke_rg" {
  name     = "deborah-work-spoke-rg"
  location = "West US"
}

# create resource group for the monitor spoke
resource "azurerm_resource_group" "deborah_monitor_spoke_rg" {
  name     = "deborah-monitor-spoke-rg"
  location = "West US"
}

# create the hub virtual network
resource "azurerm_virtual_network" "deborah_hub_vnet" {
  name                = "deborah-hub-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
}

# define the public IP address resource
resource "azurerm_public_ip" "deborah_public_ip" {
  name                = "deborah-public-ip"
  location            = "West US"
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
  sku = "Standard"
  allocation_method = "Static"
}

# create the hub vnet subnet for the gateway
resource "azurerm_subnet" "deborah_hub_gateway_subnet" {
    name             = "deborah_hub_gateway_subnet"
    resource_group_name  = azurerm_resource_group.deborah_hub_rg.name
    virtual_network_name = azurerm_virtual_network.deborah_hub_vnet.name
    address_prefixes     = ["10.0.0.0/24"]
}

# create the hub vpn gateway
resource "azurerm_virtual_network_gateway" "deborah_hub_vpn_gateway" {
  name                = "deborah-hub-vpn-gateway"
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"

  ip_configuration {
    name      = "gatewayIpConfig"
    public_ip_address_id = azurerm_public_ip.deborah_public_ip.id
    subnet_id = azurerm_subnet.deborah_hub_gateway_subnet.id
  }
}

# create the hub p2s connection
resource "azurerm_virtual_network_gateway_connection" "deborah_hub_p2s_connection" {
    name                      = "deborah-hub-p2s-connection"
    location                  = azurerm_resource_group.deborah_hub_rg.location
    resource_group_name       = azurerm_resource_group.deborah_hub_rg.name
    virtual_network_gateway_id = azurerm_virtual_network_gateway.deborah_hub_vpn_gateway.id
    type                      = "ExpressRoute"  # Specify the type of connection, it could be "Vpn" or "ExpressRoute"
  }

# create the hub firewall
resource "azurerm_firewall" "deborah_hub_firewall" {
  name                = "deborah-hub-firewall"
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
  sku_name            = "AZFW_Hub"  # Specify the desired SKU name
  sku_tier            = "Standard"  # Specify the desired SKU tier
}  

# create the firewall policy
resource "azurerm_firewall_policy" "deborah_hub_firewall_policy" {
  name                = "deborah-hub-firewall-policy"
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
}

# create the hub acr with private endpoint
resource "azurerm_container_registry" "deborah_hub_acr" {
  name                = "deborahhubacr"
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
  location            = azurerm_resource_group.deborah_hub_rg.location
  sku                 = "Standard"
}

resource "azurerm_subnet" "deborah_hub_acr_private_endpoint_subnet" {
    name                 = "deborah-hub-acr-private-endpoint-subnet"
    resource_group_name  = azurerm_resource_group.deborah_hub_rg.name
    virtual_network_name = azurerm_virtual_network.deborah_hub_vnet.name
    address_prefixes     = ["10.0.1.0/24"]  # Specify the subnet CIDR block
  }
  
resource "azurerm_private_endpoint" "deborah_hub_acr_private_endpoint" {
  name                = "deborah-hub-acr-private-endpoint"
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name

  subnet_id                    = azurerm_subnet.deborah_hub_acr_private_endpoint_subnet.id
  private_service_connection {
    name                           = "deborah-acrPrivateEndpoint"
    private_connection_resource_id = azurerm_container_registry.deborah_hub_acr.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }
}

# create the hub log analytics workspace
resource "azurerm_log_analytics_workspace" "deborah_hub_log_analytics_workspace" {
  name                = "deborah-hub-log-analytics-workspace"
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# create the work spoke vnet
resource "azurerm_virtual_network" "deborah_work_spoke_vnet" {
  name                = "deborah-work-spoke-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.deborah_work_spoke_rg.location
  resource_group_name = azurerm_resource_group.deborah_work_spoke_rg.name
}

# create work spoke subnet
resource "azurerm_subnet" "deborah_work_spoke_subnet" {
  name                 = "deborah-work-spoke-subnet"
  resource_group_name  = azurerm_resource_group.deborah_work_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.deborah_work_spoke_vnet.name
  address_prefixes     = ["10.1.0.0/24"]
}

# create work spoke nic
resource "azurerm_network_interface" "deborah_work_spoke_nic" {
    name                = "deborah-work-spoke-nic"
    location            = azurerm_resource_group.deborah_work_spoke_rg.location
    resource_group_name = azurerm_resource_group.deborah_work_spoke_rg.name
  
    ip_configuration {
      name                          = "deborah-config"
      subnet_id                     = azurerm_subnet.deborah_work_spoke_subnet.id
      private_ip_address_allocation = "Dynamic"  # You can choose "Static" if needed
    }
  }

# create monitor spoke nic
resource "azurerm_network_interface" "deborah_monitor_spoke_nic" {
    name                = "deborah-monitor-spoke-nic"
    location            = azurerm_resource_group.deborah_monitor_spoke_rg.location
    resource_group_name = azurerm_resource_group.deborah_monitor_spoke_rg.name
  
    ip_configuration {
      name                          = "deborah-config"
      subnet_id                     = azurerm_subnet.deborah_monitor_spoke_subnet.id
      private_ip_address_allocation = "Dynamic"  # You can choose "Static" if needed
    }
  }

# create work spoke vm
resource "azurerm_virtual_machine" "deborah_work_spoke_vm" {
  name                  = "deborah-work-spoke-vm"
  location              = azurerm_resource_group.deborah_work_spoke_rg.location
  resource_group_name   = azurerm_resource_group.deborah_work_spoke_rg.name
  vm_size               = "Standard_B2s"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "deborah-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  network_interface_ids = [azurerm_network_interface.deborah_work_spoke_nic.id]
}

# Create the monitor spoke VM
resource "azurerm_virtual_machine" "deborah_monitor_spoke_vm" {
  name                  = "deborah-monitor-spoke-vm"
  location              = azurerm_resource_group.deborah_monitor_spoke_rg.location
  resource_group_name   = azurerm_resource_group.deborah_monitor_spoke_rg.name
  vm_size               = "Standard_B2s"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "deborah-monitor-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  network_interface_ids = [azurerm_network_interface.deborah_monitor_spoke_nic.id]
}

# create the work spoke storage account
resource "azurerm_storage_account" "workspokestorage" {
  name                     = "workspokestorage"
  resource_group_name      = azurerm_resource_group.deborah_work_spoke_rg.name
  location                 = azurerm_resource_group.deborah_work_spoke_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# create a private endpoint for the storage account
resource "azurerm_private_endpoint" "deborah_work_spoke_storage_private_endpoint" {
  name                = "deborah-work-spoke-storage-private-endpoint"
  location            = azurerm_resource_group.deborah_work_spoke_rg.location
  resource_group_name = azurerm_resource_group.deborah_work_spoke_rg.name

  subnet_id                    = azurerm_subnet.deborah_work_spoke_subnet.id
  private_service_connection {
    name                           = "deborah-storagePrivateEndpoint"
    private_connection_resource_id = azurerm_storage_account.workspokestorage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

# create vnet for monitor spoke
resource "azurerm_virtual_network" "deborah_monitor_spoke_vnet" {
  name                = "deborah-monitor-spoke-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = azurerm_resource_group.deborah_monitor_spoke_rg.location
  resource_group_name = azurerm_resource_group.deborah_monitor_spoke_rg.name
}

# create subnet for monitor spoke
resource "azurerm_subnet" "deborah_monitor_spoke_subnet" {
  name                 = "deborah-monitor-spoke-subnet"
  resource_group_name  = azurerm_resource_group.deborah_monitor_spoke_rg.name
  virtual_network_name = azurerm_virtual_network.deborah_monitor_spoke_vnet.name
  address_prefixes     = ["10.2.0.0/24"]
}

# peerig hub vnet to work spoke vnet
resource "azurerm_virtual_network_peering" "deborah_hub_to_work_spoke" {
  name                         = "deborah-hub-to-work-spoke"
  resource_group_name          = azurerm_resource_group.deborah_hub_rg.name
  virtual_network_name         = azurerm_virtual_network.deborah_hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.deborah_work_spoke_vnet.id
  allow_virtual_network_access = true
}

# peering hub vnet to monitor spoke vnet
resource "azurerm_virtual_network_peering" "deborah_hub_to_monitor_spoke" {
  name                         = "deborah-hub-to-monitor-spoke"
  resource_group_name          = azurerm_resource_group.deborah_hub_rg.name
  virtual_network_name         = azurerm_virtual_network.deborah_hub_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.deborah_monitor_spoke_vnet.id
  allow_virtual_network_access = true
}

# create network security group for the work spoke vnet
resource "azurerm_network_security_group" "deborah_work_spoke_nsg" {
  name                = "deborah-work-spoke-nsg"
  location            = azurerm_resource_group.deborah_work_spoke_rg.location
  resource_group_name = azurerm_resource_group.deborah_work_spoke_rg.name
}

# create network security group for the monitor spoke vnet
resource "azurerm_network_security_group" "deborah_monitor_spoke_nsg" {
  name                = "deborah-monitor-spoke-nsg"
  location            = azurerm_resource_group.deborah_monitor_spoke_rg.location
  resource_group_name = azurerm_resource_group.deborah_monitor_spoke_rg.name
}

# Add nsg rule to allow traffic from the vpn gateway to the spokes vnets
resource "azurerm_network_security_rule" "deborah_vpn_gateway_to_spokes" {
  name                        = "deborah-vpn-gateway-to-spokes"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = [azurerm_virtual_network.deborah_hub_vnet.address_space[0]]  # Use the address space of the hub virtual network
  destination_address_prefix  = azurerm_virtual_network.deborah_work_spoke_vnet.address_space[0]
  resource_group_name         = azurerm_resource_group.deborah_hub_rg.name
  network_security_group_name = azurerm_network_security_group.deborah_work_spoke_nsg.name
}

# add nsg rule to allow traffic from the vpn gateeway to the monitor spoke
resource "azurerm_network_security_rule" "deborah_vpn_gateway_to_monitor_spoke" {
  name                        = "deborah-vpn-gateway-to-monitor-spoke"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = [azurerm_virtual_network.deborah_hub_vnet.address_space[0]]
  destination_address_prefix  = azurerm_virtual_network.deborah_monitor_spoke_vnet.address_space[0]
  resource_group_name         = azurerm_resource_group.deborah_hub_rg.name
  network_security_group_name = azurerm_network_security_group.deborah_monitor_spoke_nsg.name
}

# add nsg rule to allow traffic from work spoke vm to the storage storage account
resource "azurerm_network_security_rule" "deborah_work_spoke_vm_to_storage_account" {
  name                        = "deborah-work-spoke-vm-to-storage-account"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = [azurerm_virtual_network.deborah_hub_vnet.address_space[0]] 
  destination_address_prefix  = azurerm_storage_account.workspokestorage.primary_blob_endpoint
  resource_group_name         = azurerm_resource_group.deborah_work_spoke_rg.name
  network_security_group_name = azurerm_network_security_group.deborah_work_spoke_nsg.name
}

# log analytics workspace
resource "azurerm_log_analytics_workspace" "deborah_activity_log_workspace" {
  name                = "deborah-activity-log-workspace"
  location            = azurerm_resource_group.deborah_hub_rg.location
  resource_group_name = azurerm_resource_group.deborah_hub_rg.name
  sku                 = "PerGB2018"
}

# define logs 
resource "azurerm_monitor_diagnostic_setting" "deborah_activity_log_diagnostic_setting" {
  name               = "deborah-activity-log-diagnostic-setting"
  target_resource_id = azurerm_log_analytics_workspace.deborah_activity_log_workspace.id

  log {
    category = "SignInLogs"
    enabled  = true
  }

  log {
    category = "AuditLogs"
    enabled  = true
  }

  storage_account_id = azurerm_storage_account.workspokestorage.id

}
