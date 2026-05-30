# =====================================================================
# VM Windows de teste — usada para validar a conectividade pelo túnel VPN
# (RDP nela e tentar alcançar um host da rede 192.168.0.0/16 da empresa)
# =====================================================================

# IP público só para RDP de teste. O acesso é restringido por NSG ao IP da empresa.
resource "azurerm_public_ip" "vm" {
  name                = "pip-vm-test-projeto"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

# Libera RDP (3389) APENAS a partir do IP público da empresa — não expõe à internet inteira.
resource "azurerm_network_security_rule" "allow_rdp_from_office" {
  name                        = "Allow-RDP-From-Office"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = var.rdp_admin_source_ip
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.resource_group.name
  network_security_group_name = azurerm_network_security_group.workload.name
}

resource "azurerm_network_interface" "vm" {
  name                = "nic-vm-test-projeto"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet1.id # snet1 (10.100.1.0/24)
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }

  tags = local.common_tags
}

resource "azurerm_windows_virtual_machine" "test" {
  name                = "vm-test-projeto"
  computer_name       = "vm-test-projeto"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  size                = var.vm_size
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  network_interface_ids = [azurerm_network_interface.vm.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = local.common_tags
}
