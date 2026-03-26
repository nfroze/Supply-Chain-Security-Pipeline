#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Apply Kyverno supply chain security policies
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Applying Kyverno Supply Chain Policies"
echo "=========================================="

# Verify Kyverno is running
echo ""
echo "Checking Kyverno status..."
kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller
echo ""

# Apply policies in order
POLICIES=(
  "restrict-image-registries.yaml"
  "require-security-context.yaml"
  "verify-image-signature.yaml"
  "verify-slsa-provenance.yaml"
  "verify-sbom-attestation.yaml"
)

for policy in "${POLICIES[@]}"; do
  echo "Applying: ${policy}"
  kubectl apply -f "${SCRIPT_DIR}/${policy}"
done

echo ""
echo "=========================================="
echo "Policy Status"
echo "=========================================="
kubectl get clusterpolicy

echo ""
echo "All policies applied. Supply chain verification is now enforced."
echo ""
echo "To test rejection of unsigned images, run:"
echo "  kubectl run test-unsigned --image=nginx -n supply-chain-demo"
echo ""
echo "Expected result: admission webhook should reject the pod."
