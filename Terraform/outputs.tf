output "gateway_url" {
  description = "Endereço único de entrada do sistema"
  value       = "http://localhost:${var.gateway_port}"
}

output "containers" {
  description = "Containers criados"
  value = [
    docker_container.auth_db.name,
    docker_container.produtos_db.name,
    docker_container.auth_service.name,
    docker_container.produtos_service.name,
    docker_container.gateway.name,
  ]
}
