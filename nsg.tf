# =====================================================================
# Network Security Groups nas subnets de workload
# =====================================================================
# IMPORTANTE: a regra default AllowVnetInBound (65000) libera TUDO da tag
# VirtualNetwork — e essa tag INCLUI os ranges on-prem conectados via VPN.
# Ou seja, por padrão a empresa (192.168.0.0/16) teria acesso irrestrito às VMs.
# Por isso travamos abaixo: só RDP + ICMP da empresa, o resto é negado.
#
# Conjunto efetivo de regras inbound (prioridade menor = avaliada primeiro):
#   300  Allow-RDP-From-Office   TCP 3389 do IP público da empresa (internet, pré-VPN)   [vm.tf]
#   310  Allow-ICMP-From-OnPrem  ICMP de 192.168.0.0/16 (pelo túnel)                      [vm.tf]
#   320  Allow-RDP-From-OnPrem   TCP 3389 de 192.168.0.0/16 (pelo túnel)                  [aqui]
#   330  Allow-SSH-From-OnPrem   TCP 22 de 192.168.0.0/16 (pelo túnel)                    [aqui]
#   4000 Deny-All-From-OnPrem    nega o resto vindo de 192.168.0.0/16                     [aqui]
#   65000 (default) AllowVnetInBound — continua liberando o tráfego interno Azure↔Azure
#         (10.100.0.0/16), pois o Deny acima só atinge o range 192.168.0.0/16.
#
# NÃO associar NSG ao GatewaySubnet — a Azure desencoraja e pode quebrar o gateway.

resource "azurerm_network_security_group" "workload" {
  name                = "nsg-projeto-prod"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  tags = local.common_tags
}

# Libera ICMP (ping) vindo APENAS da rede da empresa, pelo túnel VPN — para testes de conectividade.
resource "azurerm_network_security_rule" "allow_icmp_from_onprem" {
  name                        = "Allow-ICMP-From-OnPrem"
  priority                    = 310
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Icmp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.onprem_address_spaces
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

# Libera RDP vindo da rede da empresa pelo túnel (acesso à VM via IP privado).
resource "azurerm_network_security_rule" "allow_rdp_from_onprem" {
  name                        = "Allow-RDP-From-OnPrem"
  priority                    = 320
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.onprem_address_spaces
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

# Libera SSH vindo da rede da empresa pelo túnel.
resource "azurerm_network_security_rule" "allow_ssh_from_onprem" {
  name                        = "Allow-SSH-From-OnPrem"
  priority                    = 330
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.onprem_address_spaces
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

# Nega todo o restante vindo da empresa (sobrepõe a default AllowVnetInBound para esse range).
# Não afeta o tráfego interno da VNet (10.100.0.0/16), que continua livre.
resource "azurerm_network_security_rule" "deny_all_from_onprem" {
  name                        = "Deny-All-From-OnPrem"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefixes     = var.onprem_address_spaces
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_subnet_network_security_group_association" "snet1" {
  subnet_id                 = azurerm_subnet.snet1.id
  network_security_group_id = azurerm_network_security_group.workload.id
}

resource "azurerm_subnet_network_security_group_association" "snet2" {
  subnet_id                 = azurerm_subnet.snet2.id
  network_security_group_id = azurerm_network_security_group.workload.id
}
