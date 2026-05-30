variable "location" {
  description = "Região onde os recursos serão criados na Azure"
  type        = string
  default     = "Brazil South"
}

# --- Site-to-Site VPN: dados do lado da empresa (on-premises) ---

variable "onprem_gateway_address" {
  description = "IP público do dispositivo de VPN (firewall/roteador) da empresa"
  type        = string
  default     = "185.99.19.242"
}

variable "onprem_address_spaces" {
  description = "Ranges de rede internos da empresa que serão alcançáveis pelo túnel (não podem sobrepor 10.100.0.0/16)"
  type        = list(string)
  default     = ["192.168.0.0/16"]
}

variable "vpn_shared_key" {
  description = "Pre-Shared Key (PSK) do túnel IPsec. NÃO commitar — definir via tfvars (gitignored) ou variável de ambiente TF_VAR_vpn_shared_key"
  type        = string
  #default     = ""
  sensitive = true
}

# --- VM Windows de teste (validar conectividade pelo túnel) ---

variable "rdp_admin_source_ip" {
  description = "IP público de onde você faz RDP na VM de teste pela internet (sua estação de admin). Diferente do WAN do SonicWall. Atualize se seu IP mudar."
  type        = string
  default     = "186.220.36.97"
}

variable "vm_size" {
  description = "Tamanho da VM de teste"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "Usuário administrador local da VM Windows"
  type        = string
  default     = "azadmin"
}

variable "vm_admin_password" {
  description = "Senha do admin da VM. Min 12 chars, 3 de 4 categorias (maiúscula/minúscula/número/símbolo). NÃO commitar — usar tfvars/env TF_VAR_vm_admin_password"
  type        = string
  #default     = ""
  sensitive = true
}