terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock" # Pour Linux/Mac
  # host = "npipe:////./pipe/docker_engine" # Décommentez cette ligne pour Windows !
}