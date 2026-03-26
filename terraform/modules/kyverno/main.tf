# ─────────────────────────────────────────────
# Kyverno Namespace
# ─────────────────────────────────────────────

resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = "kyverno"

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "supply-chain-security-pipeline"
    }
  }
}

# ─────────────────────────────────────────────
# Kyverno Helm Release
# ─────────────────────────────────────────────
# Gotchas addressed:
# - 3 replicas for HA (prevents webhook deadlock on node scaling)
# - Namespace excluded from validation (prevents bootstrap deadlock)
# - Webhook timeout increased to 30s (signature verification needs external calls)
# - IRSA annotation for ECR access
# - Resource limits to prevent noisy-neighbour on shared nodes

resource "helm_release" "kyverno" {
  name       = "kyverno"
  namespace  = kubernetes_namespace.kyverno.metadata[0].name
  repository = "https://kyverno.github.io/kyverno"
  chart      = "kyverno"
  version    = var.kyverno_chart_version
  timeout    = 600

  values = [
    yamlencode({
      replicaCount = 3

      # IRSA: annotate the admission controller service account for ECR access
      admissionController = {
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = var.kyverno_irsa_role_arn
          }
        }

        container = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }

      # Webhook configuration
      config = {
        # Exclude kyverno namespace from validation to prevent deadlock
        # If all Kyverno pods crash with failurePolicy: Fail, the cluster
        # cannot schedule new Kyverno pods without this exclusion
        webhooks = [
          {
            namespaceSelector = {
              matchExpressions = [
                {
                  key      = "kubernetes.io/metadata.name"
                  operator = "NotIn"
                  values   = ["kyverno", "kube-system"]
                }
              ]
            }
          }
        ]
      }

      # Background controller for policy reports
      backgroundController = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # Cleanup controller
      cleanupController = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # Reports controller
      reportsController = {
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # Features
      features = {
        policyExceptions = {
          enabled = true
        }
      }
    })
  ]
}
