terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# MySQL Database
resource "docker_image" "mysql" {
  name          = "mysql:8.0"
  keep_locally  = false
}

resource "docker_container" "mysql" {
  name  = var.project_name
  image = docker_image.mysql.image_id

  env = [
    "MYSQL_ROOT_PASSWORD=${var.db_password}",
    "MYSQL_DATABASE=${var.db_name}",
    "MYSQL_USER=${var.db_username}",
    "MYSQL_PASSWORD=${var.db_password}"
  ]

  ports {
    internal = 3306
    external = 3306
  }

  healthcheck {
    test     = ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    interval = "10s"
    timeout  = "5s"
    retries  = 5
  }

  networks_advanced {
    name = docker_network.app.name
  }
}

# Spring PetClinic Application
resource "docker_image" "app" {
    name = var.docker_image
  

  keep_locally = true
}

resource "docker_container" "app" {
    name  = "${var.project_name}-app"
    image = docker_image.app.image_id
    wait         = true
    wait_timeout = 120
    
  env = [
    "SPRING_DATASOURCE_URL=jdbc:mysql://${docker_container.mysql.name}:3306/${var.db_name}",
    "SPRING_DATASOURCE_USERNAME=${var.db_username}",
    "SPRING_DATASOURCE_PASSWORD=${var.db_password}",
    "SPRING_PROFILES_ACTIVE=mysql"
  ]

  ports {
    internal = 8080
    external = 8080
  }

  healthcheck {
    test     = ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
    interval = "30s"
    timeout  = "10s"
    retries  = 3
    start_period = "60s"
  }

  networks_advanced {
    name = docker_network.app.name
  }

  depends_on = [docker_container.mysql]

  logs = true
}

# Prometheus (Optional monitoring)
resource "docker_image" "prometheus" {
  count         = var.enable_prometheus ? 1 : 0
  name          = "prom/prometheus:latest"
  keep_locally  = false
}

resource "docker_container" "prometheus" {
  count = var.enable_prometheus ? 1 : 0
  name  = "${var.project_name}-prometheus"
  image = docker_image.prometheus[0].image_id

  ports {
    internal = 9090
    external = 9090
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus"
  ]

  volumes {
    host_path      = "${var.app_context}/monitoring/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }

  networks_advanced {
    name = docker_network.app.name
  }
}

# Docker Network
resource "docker_network" "app" {
  name   = "${var.project_name}-network"
  driver = "bridge"
}

# Local file for connection info
resource "local_file" "connection_info" {
  content = jsonencode({
    app_url       = "http://localhost:${docker_container.app.ports[0].external}"
    mysql_host    = docker_container.mysql.name
    mysql_port    = 3306
    mysql_user    = var.db_username
    mysql_pass    = var.db_password
    containers    = {
      app    = docker_container.app.name
      mysql  = docker_container.mysql.name
    }
  })
  filename = "${path.module}/connection-info.json"
}