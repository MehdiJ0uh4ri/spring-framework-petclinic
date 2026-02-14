# --- Réseau ---
# Crée un réseau privé pour que les conteneurs se voient entre eux
resource "docker_network" "private_network" {
  name = "petclinic_net"
}

# --- Images ---
resource "docker_image" "mysql" {
  name         = "mysql:8.0"
  keep_locally = true
}

resource "docker_image" "prometheus" {
  name         = "prom/prometheus:latest"
  keep_locally = true
}

resource "docker_image" "grafana" {
  name         = "grafana/grafana:latest"
  keep_locally = true
}

# Note: Pour l'app, on suppose que vous avez buildé l'image localement via "docker build -t petclinic:latest ."
# Terraform Docker provider gère mal le "build" direct, c'est plus simple de build avant.
resource "docker_image" "petclinic_app" {
  name         = "petclinic:latest"
  keep_locally = true
}

# --- Conteneurs ---

# 1. Base de données
resource "docker_container" "db" {
  name  = "petclinic_db"
  image = docker_image.mysql.image_id
  
  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 3306
    external = 3306
  }

  env = [
    "MYSQL_DATABASE=petclinic",
    "MYSQL_USER=petclinic",
    "MYSQL_PASSWORD=petclinic",
    "MYSQL_ROOT_PASSWORD=root"
  ]
}

# 2. Application PetClinic
resource "docker_container" "app" {
  name  = "petclinic_app"
  image = docker_image.petclinic_app.image_id
  
  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 8080
    external = 8080
  }

  env = [
    "SPRING_PROFILES_ACTIVE=mysql",
    # Notez l'utilisation du nom du conteneur "petclinic_db" comme hostname
    "SPRING_DATASOURCE_URL=jdbc:mysql://petclinic_db:3306/petclinic",
    "SPRING_DATASOURCE_USERNAME=petclinic",
    "SPRING_DATASOURCE_PASSWORD=petclinic"
  ]

  # On attend que la DB soit prête (Terraform ne gère pas nativement le "wait for healthy", c'est un point faible par rapport à Compose)
  depends_on = [docker_container.db]
}

# 3. Prometheus (Monitoring)
resource "docker_container" "prometheus" {
  name  = "petclinic_prometheus"
  image = docker_image.prometheus.image_id

  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 9090
    external = 9090
  }

  # Monte le fichier de config local
  volumes {
    host_path      = abspath("${path.cwd}/../prometheus.yml") # Chemin absolu vers la racine du projet
    container_path = "/etc/prometheus/prometheus.yml"
  }
}

# 4. Grafana (Dashboard)
resource "docker_container" "grafana" {
  name  = "petclinic_grafana"
  image = docker_image.grafana.image_id

  networks_advanced {
    name = docker_network.private_network.name
  }

  ports {
    internal = 3000
    external = 3000
  }
}