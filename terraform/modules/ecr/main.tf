# ─────────────────────────────────────────────
# ECR Repository — Application Images
# ─────────────────────────────────────────────

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app"
  }
}

# ─────────────────────────────────────────────
# ECR Repository Policy — Restrict access
# ─────────────────────────────────────────────

data "aws_caller_identity" "current" {}

resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ]
      }
    ]
  })
}

# NOTE: No lifecycle policy configured intentionally.
# ECR lifecycle policies cannot distinguish between image manifests
# and OCI artifact manifests (signatures, SBOMs, attestations).
# A lifecycle policy could delete the primary image and orphan its
# cosign signatures and SBOM attestations, or vice versa.
# Manual cleanup is preferred in a supply chain security context.
