variable "kubeconfig_raw" {
  type        = string
  description = "Raw kubeconfig YAML content (from KUBECONFIG_DEV GitHub Secret)"
  sensitive   = true
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for the petclinic application"
  default     = "petclinic"
}

variable "ghcr_username" {
  type        = string
  description = "GitHub username for GHCR image pull secret"
}

variable "ghcr_token" {
  type        = string
  description = "GitHub token with read:packages scope"
  sensitive   = true
}