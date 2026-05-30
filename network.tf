resource "azurerm_resource_group" "resource_group" {
  name     = "rg-vnet-projeto-prod"
  location = var.location

  tags = local.common_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "projeto-vnet"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  address_space       = ["10.100.0.0/16"]

  tags = local.common_tags
}

resource "azurerm_subnet" "snet1" {
  name                 = "snet1"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.1.0/24"]
}

resource "azurerm_subnet" "snet2" {
  name                 = "snet2"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.2.0/24"]
}

# Subnet exigida pelo Azure para hospedar o VPN Gateway.
# O nome DEVE ser exatamente "GatewaySubnet". Recomendado /27 (folga p/ futuro: active-active, ExpressRoute coexistente).
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.100.255.0/27"]
}
