output "namespace" {
  value       = kubernetes_namespace.petclinic.metadata[0].name
  description = "Kubernetes namespace where petclinic is deployed"
}

output "ghcr_pull_secret_name" {
  value       = kubernetes_secret.ghcr_pull_secret.metadata[0].name
  description = "Name of the GHCR image pull secret"
}