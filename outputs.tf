output "vnet_id" {
  description = "The id of the newly created vNet"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_subnets" {
  description = "The ids of subnets created inside the newly created vNet"
  value       = [azurerm_subnet.snet1.id, azurerm_subnet.snet2.id]
}

output "vpn_gateway_public_ip" {
  description = "IP público do VPN Gateway — informe este IP ao time de rede da empresa para configurar o lado deles"
  value       = azurerm_public_ip.vpn.ip_address
}

output "vpn_gateway_id" {
  description = "ID do VPN Gateway"
  value       = azurerm_virtual_network_gateway.vpn.id
}

output "vm_test_public_ip" {
  description = "IP público da VM de teste (RDP a partir do IP da empresa)"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_test_private_ip" {
  description = "IP privado da VM de teste na VNet (use para validar acesso vindo da rede da empresa pelo túnel)"
  value       = azurerm_network_interface.vm.private_ip_address
}