terraform {
  required_version = ">= 1.5"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Se docker_host ficar vazio, o provider usa o padrão (ou a variável de ambiente DOCKER_HOST)
provider "docker" {
  host = var.docker_host != "" ? var.docker_host : null
}

# ---------------------------------------------------------------
# Rede e volumes
# ---------------------------------------------------------------
resource "docker_network" "techstore" {
  name = "techstore-net"
}

resource "docker_volume" "auth_db_data" {
  name = "techstore-auth-db-data"
}

resource "docker_volume" "produtos_db_data" {
  name = "techstore-produtos-db-data"
}

# ---------------------------------------------------------------
# Imagens
# ---------------------------------------------------------------
resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_image" "auth" {
  name         = "techstore-auth:latest"
  keep_locally = true

  build {
    context = "${path.module}/../auth-service"
  }

  # Reconstrói a imagem quando algum arquivo do serviço mudar
  triggers = {
    fonte = sha1(join("", [
      for f in fileset("${path.module}/../auth-service", "*") :
      filesha1("${path.module}/../auth-service/${f}")
    ]))
  }
}

resource "docker_image" "produtos" {
  name         = "techstore-produtos:latest"
  keep_locally = true

  build {
    context = "${path.module}/../produtos-service"
  }

  triggers = {
    fonte = sha1(join("", [
      for f in fileset("${path.module}/../produtos-service", "*") :
      filesha1("${path.module}/../produtos-service/${f}")
    ]))
  }
}

resource "docker_image" "gateway" {
  name         = "techstore-gateway:latest"
  keep_locally = true

  build {
    context = "${path.module}/../gateway"
  }

  triggers = {
    fonte = sha1(join("", [
      for f in fileset("${path.module}/../gateway", "*") :
      filesha1("${path.module}/../gateway/${f}")
    ]))
  }
}

# ---------------------------------------------------------------
# Banco de Usuários
# ---------------------------------------------------------------
resource "docker_container" "auth_db" {
  name    = "techstore-auth-db"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  env = [
    "POSTGRES_USER=techstore",
    "POSTGRES_PASSWORD=${var.auth_db_password}",
    "POSTGRES_DB=auth_db",
  ]

  volumes {
    volume_name    = docker_volume.auth_db_data.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name    = docker_network.techstore.name
    aliases = ["auth-db"]
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U techstore -d auth_db"]
    interval = "5s"
    timeout  = "5s"
    retries  = 10
  }

  # Espera o banco ficar saudável antes de seguir
  wait         = true
  wait_timeout = 120
}

# ---------------------------------------------------------------
# Banco de Produtos
# ---------------------------------------------------------------
resource "docker_container" "produtos_db" {
  name    = "techstore-produtos-db"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  env = [
    "POSTGRES_USER=techstore",
    "POSTGRES_PASSWORD=${var.produtos_db_password}",
    "POSTGRES_DB=produtos_db",
  ]

  volumes {
    volume_name    = docker_volume.produtos_db_data.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name    = docker_network.techstore.name
    aliases = ["produtos-db"]
  }

  healthcheck {
    test     = ["CMD-SHELL", "pg_isready -U techstore -d produtos_db"]
    interval = "5s"
    timeout  = "5s"
    retries  = 10
  }

  wait         = true
  wait_timeout = 120
}

# ---------------------------------------------------------------
# Serviço de Autenticação/Usuários (sem porta publicada: só o gateway acessa)
# ---------------------------------------------------------------
resource "docker_container" "auth_service" {
  name    = "techstore-auth-service"
  image   = docker_image.auth.image_id
  restart = "unless-stopped"

  env = [
    "DB_HOST=auth-db",
    "DB_PORT=5432",
    "DB_USER=techstore",
    "DB_PASSWORD=${var.auth_db_password}",
    "DB_NAME=auth_db",
    "JWT_SECRET=${var.jwt_secret}",
  ]

  networks_advanced {
    name    = docker_network.techstore.name
    aliases = ["auth-service"]
  }

  depends_on = [docker_container.auth_db]
}

# ---------------------------------------------------------------
# Serviço de Produtos (sem porta publicada: só o gateway acessa)
# ---------------------------------------------------------------
resource "docker_container" "produtos_service" {
  name    = "techstore-produtos-service"
  image   = docker_image.produtos.image_id
  restart = "unless-stopped"

  env = [
    "DB_HOST=produtos-db",
    "DB_PORT=5432",
    "DB_USER=techstore",
    "DB_PASSWORD=${var.produtos_db_password}",
    "DB_NAME=produtos_db",
    "JWT_SECRET=${var.jwt_secret}",
  ]

  networks_advanced {
    name    = docker_network.techstore.name
    aliases = ["produtos-service"]
  }

  depends_on = [docker_container.produtos_db]
}

# ---------------------------------------------------------------
# API Gateway (Nginx) - único ponto de entrada
# ---------------------------------------------------------------
resource "docker_container" "gateway" {
  name    = "techstore-gateway"
  image   = docker_image.gateway.image_id
  restart = "unless-stopped"

  ports {
    internal = 8080
    external = var.gateway_port
  }

  networks_advanced {
    name    = docker_network.techstore.name
    aliases = ["gateway"]
  }

  depends_on = [
    docker_container.auth_service,
    docker_container.produtos_service,
  ]
}
