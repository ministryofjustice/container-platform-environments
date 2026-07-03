<<<<<<< HEAD
# Debug output removed to avoid persisting aggregated namespace manifests in Terraform state and CI logs.
=======
output "namespaces_debug" {
  description = "Temporary debug output for aggregated namespace manifests"
  value       = local.namespaces
}
>>>>>>> d49c90b (Initial set up and identity)
