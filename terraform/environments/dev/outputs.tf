output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = module.eks.cluster_version
}

output "ecr_repository_url" {
  description = "ECR repository URL for application images"
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN"
  value       = module.ecr.repository_arn
}

output "kyverno_irsa_role_arn" {
  description = "IAM role ARN for Kyverno IRSA (ECR access)"
  value       = module.eks.kyverno_irsa_role_arn
}

output "kyverno_namespace" {
  description = "Namespace where Kyverno is installed"
  value       = module.kyverno.kyverno_namespace
}

output "kyverno_chart_version" {
  description = "Kyverno Helm chart version"
  value       = module.kyverno.kyverno_chart_version
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
