output "kyverno_namespace" {
  description = "Namespace where Kyverno is installed"
  value       = kubernetes_namespace.kyverno.metadata[0].name
}

output "kyverno_release_name" {
  description = "Helm release name"
  value       = helm_release.kyverno.name
}

output "kyverno_chart_version" {
  description = "Installed Kyverno chart version"
  value       = helm_release.kyverno.version
}
