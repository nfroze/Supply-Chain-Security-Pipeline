# ─────────────────────────────────────────────
# EKS Cluster IAM Role
# ─────────────────────────────────────────────

resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ─────────────────────────────────────────────
# EKS Cluster Security Group
# ─────────────────────────────────────────────

resource "aws_security_group" "cluster" {
  name_prefix = "${var.project_name}-${var.environment}-eks-cluster-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow worker nodes to communicate with cluster API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}-eks"
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions  = true
  }

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_controller,
    aws_cloudwatch_log_group.eks,
  ]
}

# ─────────────────────────────────────────────
# KMS Key for EKS Secrets Encryption
# ─────────────────────────────────────────────

resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-kms"
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ─────────────────────────────────────────────
# CloudWatch Log Group for EKS
# ─────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project_name}-${var.environment}-eks/cluster"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-logs"
  }
}

# ─────────────────────────────────────────────
# OIDC Provider for IRSA
# ─────────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-oidc"
  }
}

# ─────────────────────────────────────────────
# Node Group IAM Role
# ─────────────────────────────────────────────

resource "aws_iam_role" "node_group" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_ecr_read" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# ─────────────────────────────────────────────
# EKS Managed Node Group
# ─────────────────────────────────────────────

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role        = "worker"
    environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr_read,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-node-group"
  }
}

# ─────────────────────────────────────────────
# Kyverno IRSA Role (ECR image verification)
# ─────────────────────────────────────────────

locals {
  oidc_provider     = replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
}

resource "aws_iam_role" "kyverno" {
  name = "${var.project_name}-${var.environment}-kyverno-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider}:sub" = "system:serviceaccount:kyverno:kyverno-admission-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-kyverno-irsa"
  }
}

resource "aws_iam_role_policy" "kyverno_ecr" {
  name = "${var.project_name}-${var.environment}-kyverno-ecr-policy"
  role = aws_iam_role.kyverno.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

# EKS Access: cluster creator admin permissions are granted via
# access_config.bootstrap_cluster_creator_admin_permissions = true
# in the aws_eks_cluster resource above. No separate access entry needed.
