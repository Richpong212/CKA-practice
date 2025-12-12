#!/usr/bin/env bash
# CKAD 2025 Practice – Cleanup Script
# Run this when you want to remove all practice resources
# created by prep.sh and your solutions.

set -euo pipefail

BASE_DIR="${HOME}"

echo "=== Cleaning CKAD practice environment ==="
echo "Using BASE_DIR: ${BASE_DIR}"
echo

# ------------ Namespaces (wipes everything inside them) ------------
for ns in meta dev cachelayer netpol-chain cpu-load production; do
  echo "Deleting namespace: $ns"
  kubectl delete ns "$ns" --ignore-not-found=true
done
echo

# ------------ Default namespace: Deployments ------------
echo "Deleting Deployments in default namespace..."
kubectl delete deploy \
  billing-api \
  store-deploy \
  internal-api \
  app-stable \
  app-canary \
  web-app \
  shop-api \
  video-api \
  syncer \
  dashboard \
  old-deploy \
  broken-app \
  --ignore-not-found=true || true

# Extra ones from older labs (safe to attempt)
kubectl delete deploy \
  payments \
  backend \
  accounts-api \
  web-deploy \
  db-api \
  --ignore-not-found=true || true
echo

# ------------ Default namespace: Pods (standalone) ------------
echo "Deleting standalone Pods in default namespace..."
kubectl delete pod \
  startup-pod \
  healthz \
  audit-runner \
  winter \
  redis32 \
  resource-pod \
  livecheck \
  broken-init \
  --ignore-not-found=true || true
echo

# (cpu-busy pods live in cpu-load ns and will be removed with the namespace)

# ------------ Default namespace: Services ------------
echo "Deleting Services in default namespace..."
kubectl delete svc \
  store-svc \
  internal-api-svc \
  app-svc \
  web-app-svc \
  video-svc \
  client-svc \
  external-db \
  path-test-svc \
  --ignore-not-found=true || true
echo

# ------------ Default namespace: Ingresses ------------
echo "Deleting Ingresses in default namespace..."
kubectl delete ingress \
  store-ingress \
  internal-api-ingress \
  client-ingress \
  web-bad-ingress \
  bad-path-ingress \
  api-ing \
  --ignore-not-found=true || true
echo

# ------------ Default namespace: CronJobs ------------
echo "Deleting CronJobs in default namespace..."
kubectl delete cronjob \
  metrics-job \
  hourly-report \
  backup-cron \
  workers-batch \
  --ignore-not-found=true || true
echo

# ------------ RBAC in default namespace ------------
echo "Deleting RBAC objects in default namespace..."
kubectl delete role audit-role       -n default --ignore-not-found=true || true
kubectl delete rolebinding audit-rb  -n default --ignore-not-found=true || true
kubectl delete sa audit-sa wrong-sa  -n default --ignore-not-found=true || true
echo

# ------------ RBAC in meta namespace (if still around) ------------
echo "Deleting RBAC objects in meta namespace (if ns still exists)..."
kubectl delete role        dev-deploy-role -n meta --ignore-not-found=true || true
kubectl delete rolebinding dev-deploy-rb   -n meta --ignore-not-found=true || true
kubectl delete sa          dev-sa          -n meta --ignore-not-found=true || true
echo

# ------------ NetworkPolicies in netpol-chain ------------
echo "Deleting NetworkPolicies in netpol-chain (if ns still exists)..."
kubectl delete networkpolicy \
  deny-all \
  allow-frontend-to-backend \
  allow-backend-to-db \
  -n netpol-chain \
  --ignore-not-found=true || true
echo

# ------------ Local files on node ------------
echo "Removing local practice files under ${BASE_DIR}..."
rm -f "${BASE_DIR}/api-app.tar" \
      "${BASE_DIR}/old.yaml" \
      "${BASE_DIR}/client-ingress.yaml" \
      "${BASE_DIR}/broken-app.yaml" || true

# Docker build context dir (optional)
rm -rf "${BASE_DIR}/api-app" || true

echo "Cleaning /opt/winter files (ignore if permission denied)..."
# Logs written during exercises
sudo rm -f /opt/winter/logs.txt 2>/dev/null || true
sudo rm -f /opt/winter/highest.txt 2>/dev/null || true

# Optionally remove the whole winter dir (will fail silently if not empty or no perms)
sudo rmdir /opt/winter 2>/dev/null || true

echo
echo "=== CKAD practice cleanup complete ==="
