variable "project_name" {
  type    = string
  default = "petclinic"
}

variable "app_version" {
  type    = string
  default = "latest"
}

variable "app_context" {
  type        = string
  description = "Build context (usually repo root)"
  default     = "."
}

variable "db_name" {
  type    = string
  default = "petclinic"
}

variable "db_username" {
  type      = string
  sensitive = true # Hides value in CLI output
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "enable_prometheus" {
  type    = bool
  default = false
}

variable "docker_image" {
  description = "The full Docker image name to deploy (e.g., ghcr.io/user/repo:sha)"
  type        = string
}