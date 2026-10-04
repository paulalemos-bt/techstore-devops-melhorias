variable "docker_host" {
  description = "Endereço do Docker. Deixe vazio para o padrão. No Windows costuma ser npipe:////./pipe/docker_engine"
  type        = string
  default     = ""
}

variable "auth_db_password" {
  description = "Senha do Banco de Usuários"
  type        = string
  default     = "techstore"
  sensitive   = true
}

variable "produtos_db_password" {
  description = "Senha do Banco de Produtos"
  type        = string
  default     = "techstore"
  sensitive   = true
}

variable "jwt_secret" {
  description = "Segredo usado para assinar e validar os tokens JWT (igual nos dois serviços)"
  type        = string
  default     = "troque-este-segredo"
  sensitive   = true
}

variable "gateway_port" {
  description = "Porta do gateway no seu computador"
  type        = number
  default     = 8080
}
