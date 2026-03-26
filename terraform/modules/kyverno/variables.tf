variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kyverno_chart_version" {
  description = "Kyverno Helm chart version"
  type        = string
  default     = "3.2.6"
}

variable "kyverno_irsa_role_arn" {
  description = "IAM role ARN for Kyverno IRSA (ECR access)"
  type        = string
}
