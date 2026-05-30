# =====================================================================
# Site-to-Site VPN (IPsec) entre a VNet Azure e a rede da empresa
# =====================================================================

# IP público do gateway. SKU Standard + Static é o exigido/recomendado
# para gateways VPN não-Basic (Basic SKU está em depreciação).
# zones = 1,2,3: obrigatório para SKUs AZ (VpnGw1AZ) — o IP precisa ser zone-redundant.
resource "azurerm_public_ip" "vpn" {
  name                = "pip-vpngw-projeto-prod"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = local.common_tags
}

# VPN Gateway (route-based). VpnGw1AZ/Generation1 é o baseline de produção.
# OBS: o SKU non-AZ "VpnGw1" não pode mais ser criado desde 01/nov/2025 — usar a variante AZ.
# VpnGw1AZ só suporta Generation1 (Gen2 começa no VpnGw2AZ). Pode subir para VpnGw2AZ+ se precisar de mais throughput/BGP.
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vpngw-projeto-prod"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type          = "Vpn"
  vpn_type      = "RouteBased"
  active_active = false
  sku           = "VpnGw1AZ"
  generation    = "Generation1"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = local.common_tags

  # NOTA: em produção de verdade, reativar a trava abaixo para evitar destroy acidental.
  # Removida porque este é um ambiente de experimento (destroy/recreate frequente).
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Representa a rede on-premises da empresa (lado remoto do túnel).
resource "azurerm_local_network_gateway" "onprem" {
  name                = "lng-projeto-empresa"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  gateway_address = var.onprem_gateway_address
  address_space   = var.onprem_address_spaces

  tags = local.common_tags
}

# Conexão IPsec que amarra o gateway Azure ao gateway da empresa.
resource "azurerm_virtual_network_gateway_connection" "onprem" {
  name                = "cn-projeto-empresa"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem.id
  shared_key                 = var.vpn_shared_key

  # SonicOS 7 funciona melhor com IKEv2.
  connection_protocol = "IKEv2"

  # Default: restaura a condição que CONECTOU na primeira vez (Azure pode iniciar e responder).
  # ResponderOnly forçava só o caminho "SonicWall inicia", que falhava no KE.
  connection_mode = "Default"

  tags = local.common_tags

  # Política casada com o SonicWall TZ 370 / SonicOS 7.3.1.
  # ESTES valores DEVEM ser replicados EXATAMENTE no SonicWall (ver bloco de instruções no fim do arquivo).
  # Sem custom policy, o Azure negocia uma proposta default que o TZ costuma recusar -> túnel preso em "Connecting".
  ipsec_policy {
    # Fase 1 (IKE)
    ike_encryption = "AES256"
    ike_integrity  = "SHA256"
    # DH Group 14: valor da config original que CONECTOU na primeira vez. (Voltamos do 2, que foi só teste.)
    dh_group = "DHGroup14"

    # Fase 2 (IPsec / ESP)
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "None" # PFS DESLIGADO: a troca de KEY Payload do PFS falhava com o SonicWall route-based
    # (log do TZ: "IKEv2 Payload processing error; Type: KEY Payload"). Desabilitar PFS nos DOIS lados resolve.

    sa_lifetime = 28800
  }

  # Se você configurar o SonicWall como "Site to Site" clássico (policy-based, com redes
  # de origem/destino específicas) em vez de "Tunnel Interface" (route-based), descomente:
  # use_policy_based_traffic_selectors = true
}

# =====================================================================
# CONFIGURAÇÃO CORRESPONDENTE NO SONICWALL TZ 370 (SonicOS 7.3.1)
# Modo route-based (Tunnel Interface). São 3 passos, NESTA ORDEM:
# =====================================================================
#
# ---------------------------------------------------------------------
# PASSO 1 — Criar a VPN policy do tipo Tunnel Interface
#   Network > IPSec VPN > Rules and Settings > Add
#
#   Aba GENERAL
#     Policy Type:            Tunnel Interface   (route-based)
#     Authentication Method:  IKE using Preshared Secret
#     IPsec Primary Gateway:  <output vpn_gateway_public_ip>   (IP público do gateway Azure)
#     Shared Secret:          <mesma PSK de var.vpn_shared_key>
#     IKE ID local/peer:      IP Address (deixar default)
#
#   Aba PROPOSALS
#     IKE (Phase 1)
#       Exchange:             IKEv2 Mode
#       DH Group:             Group 14
#       Encryption:           AES-256
#       Authentication:       SHA256
#       Life Time (sec):      28800
#     IPsec (Phase 2)
#       Protocol:             ESP
#       Encryption:           AES-256
#       Authentication:       SHA256
#       Enable Perfect Forward Secrecy: DESMARCADO (PFS off — casa com pfs_group=None na Azure)
#       Life Time (sec):      28800
#
#   Aba ADVANCED
#       Enable Keep Alive:    marcado (mantém o túnel ativo)
#
# ---------------------------------------------------------------------
# PASSO 2 — Criar a Tunnel Interface (NÃO é criada automaticamente nesta versão)
#   Network > System > Interfaces > Add Interface > VPN Tunnel Interface
#     Zone:                   escolher/criar uma zona (ex.: VPN ou WAN)
#     VPN Policy:             selecionar a policy criada no PASSO 1
#     IP Address:             169.254.250.1
#     Subnet Mask:            255.255.255.252   (/30)
#
#   *** CAUSA RAIZ QUE NOS CUSTOU HORAS — LEIA ISTO ***
#   O SonicOS 7.3.1 EXIGE IP estático na tunnel interface. Esse IP é um endereço
#   de TRÂNSITO PRIVADO local (link-local 169.254.x.x), arbitrário p/ roteamento estático.
#   NUNCA use aqui o IP público do gateway da Azure (o peer). Se você puser o IP do peer
#   (ex.: 20.201.37.122), o SonicWall cria uma rota conectada para a rede do peer apontando
#   para a própria tunnel interface -> os pacotes de IKE para o gateway são jogados DENTRO
#   do túnel (down) em vez de saírem pela WAN -> timeout/retransmit e
#   "IKEv2 Payload processing error; Type: KEY Payload; Error 12". Sintoma: conecta 1x e nunca mais.
#   Regras do IP: NÃO ser o IP do peer; NÃO sobrepor 10.100.0.0/16 (VNet) nem 192.168.0.0/16 (LAN).
#
# ---------------------------------------------------------------------
# PASSO 3 — Criar a rota estática apontando para a Tunnel Interface
#   Network > System > Routing > Add
#     Source:                 Any
#     Destination:            10.100.0.0/16   (a VNet Azure)
#     Service:                Any
#     Interface:              a Tunnel Interface criada no PASSO 2
#     Gateway:                0.0.0.0 (deixar vazio/zero — é interface de túnel)
#
#   Sem o PASSO 3 o túnel fecha mas o tráfego para 10.100.0.0/16 não entra nele.
# =====================================================================
