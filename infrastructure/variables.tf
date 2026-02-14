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
  default   = "petclinic"
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "enable_prometheus" {
  type    = bool
  default = false
}