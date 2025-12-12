#!/usr/bin/env bash
# CKAD 2025 – Trouble Spots Mock (10 Exercises) – Environment Prep
# Safe to run as any user. Uses $HOME for files.

set -euo pipefail

BASE_DIR="${HOME}/ckad-mock10"
mkdir -p "${BASE_DIR}"

echo "=== CKAD Mock10 prep ==="
echo "BASE_DIR: ${BASE_DIR}"
echo

# Helper
apply() { kubectl apply -f - >/dev/null; }
apply_ns() { kubectl get ns "$1" >/dev/null 2>&1 || kubectl create ns "$1" >/dev/null; }

# Namespaces used
for ns in inglab canarylab rbaclab netlab cronlab resourcelab docklab svclab; do
  echo "Creating namespace: $ns"
  apply_ns "$ns"
done
echo

############################################
# EX 1: Ingress path/host -> service (curl returns 404/NotFound now)
############################################
echo "[EX1] Creating backend deploy + svc + WRONG ingress..."
kubectl apply -n inglab -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 1
  selector:
    matchLabels: { app: backend }
  template:
    metadata:
      labels: { app: backend }
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
spec:
  selector:
    app: backend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ing
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /wrong
        pathType: Prefix
        backend:
          service:
            name: wrong-svc
            port:
              number: 80
EOF
echo

############################################
# EX 2: Service selector broken (svc points nowhere)
############################################
echo "[EX2] Creating web deployment + BROKEN service selector..."
kubectl apply -n svclab -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 1
  selector:
    matchLabels: { app: web }
  template:
    metadata:
      labels: { app: web }
    spec:
      containers:
      - name: web
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: wrong
  ports:
  - port: 80
    targetPort: 80
EOF
echo

############################################
# EX 3: Canary 20% traffic + max 10 pods, "same deployment as stable"
# We simulate by replicas: stable=8, canary=2 (total 10).
# Service selects app=api (both). Canary identified by version=v2.
############################################
echo "[EX3] Creating stable + canary skeleton (wrong replicas/labels)..."
kubectl apply -n canarylab -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: api-svc
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-stable
spec:
  replicas: 5
  selector:
    matchLabels: { app: api, version: v1 }
  template:
    metadata:
      labels: { app: api, version: v1 }
    spec:
      containers:
      - name: api
        image: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-canary
spec:
  replicas: 5
  selector:
    matchLabels: { app: api, version: v2 }
  template:
    metadata:
      labels: { app: api, version: v2 }
    spec:
      containers:
      - name: api
        image: nginx
EOF
echo

############################################
# EX 4: RBAC – read logs, fix SA/Role/RoleBinding, update deployment SA
# Pod tries: kubectl get pods -n rbaclab (will be forbidden)
############################################
echo "[EX4] Creating rbac deployment with wrong service account..."
kubectl apply -n rbaclab -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wrong-sa
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: audit-agent
spec:
  replicas: 1
  selector:
    matchLabels: { app: audit-agent }
  template:
    metadata:
      labels: { app: audit-agent }
    spec:
      serviceAccountName: wrong-sa
      containers:
      - name: kubectl
        image: bitnami/kubectl:latest
        command: ["sh","-c"]
        args:
        - |
          while true; do
            echo "[audit-agent] trying to list pods..."
            kubectl get pods -n rbaclab || true
            sleep 6
          done
EOF
echo

############################################
# EX 5: RBAC – second one: must bind role to SA and patch pod SA
############################################
echo "[EX5] Creating a standalone Pod that needs correct SA..."
kubectl apply -n rbaclab -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: inspector
spec:
  serviceAccountName: wrong-sa
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["sh","-c"]
    args:
    - |
      while true; do
        echo "[inspector] trying to get configmaps..."
        kubectl get configmaps -n rbaclab || true
        sleep 6
      done
EOF
echo

# A configmap exists so the “get configmaps” is meaningful
kubectl apply -n rbaclab -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: target-cm
data:
  a: b
EOF
echo

############################################
# EX 6: NetworkPolicy – DO NOT TOUCH policies. Only fix labels on pods.
# Policies allow: frontend -> backend, backend -> db. Pods have wrong role labels.
############################################
echo "[EX6] Creating netpol chain + wrong labels + new pod needs 2 labels..."
kubectl apply -n netlab -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    role: front
spec:
  containers:
  - name: web
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  labels:
    role: back
spec:
  containers:
  - name: api
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: db
  labels:
    role: database
spec:
  containers:
  - name: db
    image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: newpod
  labels:
    role: something
spec:
  containers:
  - name: x
    image: nginx
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      role: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
spec:
  podSelector:
    matchLabels:
      role: db
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: backend
EOF
echo

############################################
# EX 7: CronJob – must exit after 8 seconds WITHOUT sleep, test manually
############################################
echo "[EX7] Creating CronJob with WRONG command (runs forever)..."
kubectl apply -n cronlab -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: quick-exit
spec:
  schedule: "*/2 * * * *"
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: runner
            image: busybox
            command: ["sh","-c"]
            args:
            - |
              echo "should exit after ~8s, but currently loops forever"
              while true; do :; done
EOF
echo

############################################
# EX 8: Ingress “create it from file” with invalid pathType (apply will fail)
############################################
echo "[EX8] Writing broken ingress manifest file (invalid pathType)..."
cat > "${BASE_DIR}/broken-ingress.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: broken-ing
  namespace: inglab
spec:
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: InvalidType
        backend:
          service:
            name: backend-svc
            port:
              number: 80
EOF
echo "Wrote: ${BASE_DIR}/broken-ingress.yaml"
echo

############################################
# EX 9: Resources + existing LimitRange must be halved + deployment must have resources
############################################
echo "[EX9] Creating LimitRange (to halve) + deployment without resources..."
kubectl apply -n resourcelab -f - <<'EOF'
apiVersion: v1
kind: LimitRange
metadata:
  name: dev-limits
spec:
  limits:
  - type: Container
    defaultRequest:
      cpu: "400m"
      memory: "256Mi"
    default:
      cpu: "800m"
      memory: "512Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
spec:
  replicas: 1
  selector:
    matchLabels: { app: payments }
  template:
    metadata:
      labels: { app: payments }
    spec:
      containers:
      - name: api
        image: nginx
EOF
echo

############################################
# EX 10: Resources + ResourceQuota requests halved, and limits must be 2x requests
############################################
echo "[EX10] Creating ResourceQuota (to halve) + deployment without resources..."
kubectl apply -n resourcelab -f - <<'EOF'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
spec:
  hard:
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: report-api
spec:
  replicas: 1
  selector:
    matchLabels: { app: report-api }
  template:
    metadata:
      labels: { app: report-api }
    spec:
      containers:
      - name: api
        image: nginx
EOF
echo

############################################
# Docker task files (used by EX 3/10? separate but you’ll practice)
############################################
echo "[Docker] Preparing Dockerfile under ${BASE_DIR}/api-image ..."
mkdir -p "${BASE_DIR}/api-image"
cat > "${BASE_DIR}/api-image/Dockerfile" <<'EOF'
FROM nginx:alpine
RUN echo "Hello from CKAD docker task" > /usr/share/nginx/html/index.html
EOF
echo "Dockerfile written: ${BASE_DIR}/api-image/Dockerfile"
echo

echo "=== CKAD Mock10 prep COMPLETE ==="
echo "Next: attempt questions in questions.md, then run ./check.sh"
