#!/usr/bin/env bash
# CKAD 2025 Practice – Environment Prep
# This script is safe to run as *any* user – it uses $HOME instead of /root.

set -euo pipefail

BASE_DIR="${HOME}"

echo "=== CKAD practice environment prep ==="
echo "Using BASE_DIR: ${BASE_DIR}"
echo

# ---------------- Namespaces ----------------
for ns in meta dev cachelayer netpol-chain cpu-load production; do
  echo "Creating namespace: $ns"
  kubectl get ns "$ns" >/dev/null 2>&1 || kubectl create ns "$ns"
done
echo

# ---------------- Q1: billing-api with hardcoded env vars ----------------
echo "Creating Deployment billing-api (hardcoded env vars)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: billing-api
  template:
    metadata:
      labels:
        app: billing-api
    spec:
      containers:
        - name: api
          image: nginx
          env:
            - name: DB_USER
              value: "admin"
            - name: DB_PASS
              value: "SuperSecret123"
EOF
echo

# ---------------- Q2: store-deploy + svc + misconfigured ingress ----------------
echo "Creating store deployment, service and broken ingress..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: store-deploy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: store
  template:
    metadata:
      labels:
        app: store
    spec:
      containers:
        - name: web
          image: nginx
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: store-svc
  namespace: default
spec:
  selector:
    app: store
  ports:
    - port: 8080
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: store-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /wrong
            pathType: ImplementationSpecific
            backend:
              service:
                name: wrong-svc
                port:
                  number: 80
EOF
echo

# ---------------- Q3: internal-api deploy + svc ----------------
echo "Creating internal-api deployment and service..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: internal-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: internal-api
  template:
    metadata:
      labels:
        app: internal-api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 3000
---
apiVersion: v1
kind: Service
metadata:
  name: internal-api-svc
  namespace: default
spec:
  selector:
    app: internal-api
  ports:
    - port: 3000
      targetPort: 3000
EOF
echo

# ---------------- Q4: dev-deployment (RBAC issue in meta) ----------------
echo "Creating dev-deployment in namespace meta (RBAC issue)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-deployment
  namespace: meta
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-deployment
  template:
    metadata:
      labels:
        app: dev-deployment
    spec:
      containers:
        - name: runner
          image: bitnami/kubectl:latest
          command: ["/bin/sh","-c"]
          args:
            - |
              while true; do
                echo "Trying to list deployments..."
                kubectl get deployments -n meta || echo "Forbidden?"
                sleep 10
              done
EOF
echo

# ---------------- Q5: broken startup-pod ----------------
echo "Creating broken startup-pod (missing /app/start.sh)..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: startup-pod
  namespace: default
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh","-c"]
      args: ["/app/start.sh"]
EOF
echo

# ---------------- Q6: Prepare Dockerfile under $HOME/api-app ----------------
echo "Preparing ${BASE_DIR}/api-app with sample Dockerfile..."
mkdir -p "${BASE_DIR}/api-app"
cat > "${BASE_DIR}/api-app/Dockerfile" <<'EOF'
FROM nginx:alpine
RUN echo "Hello from CKAD practice image" > /usr/share/nginx/html/index.html
EOF
echo "Dockerfile written to ${BASE_DIR}/api-app/Dockerfile"
echo

# ---------------- Q7: Namespace dev placeholder (no resources yet) ----------------
echo "Namespace dev ready for ResourceQuota and Pod question."
echo

# ---------------- Q8: Deprecated deployment manifest at $HOME/old.yaml ----------------
echo "Writing deprecated deployment manifest to ${BASE_DIR}/old.yaml..."
cat > "${BASE_DIR}/old.yaml" <<'EOF'
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: old-deploy
  namespace: default
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: old-app
    spec:
      containers:
        - name: old-container
          image: nginx:1.14
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: "invalid"
      maxUnavailable: "invalid"
EOF
echo

# ---------------- Q9: app-stable + app-svc ----------------
echo "Creating app-stable deployment and app-svc..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: core
      version: v1
  template:
    metadata:
      labels:
        app: core
        version: v1
    spec:
      containers:
        - name: app
          image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: app-svc
  namespace: default
spec:
  selector:
    app: core
  ports:
    - port: 80
      targetPort: 80
EOF
echo

# ---------------- Q10: web-app + broken web-app-svc ----------------
echo "Creating web-app and broken web-app-svc..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
        - name: web
          image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: default
spec:
  selector:
    app: wronglabel
  ports:
    - port: 80
      targetPort: 80
EOF
echo

# ---------------- Q11: healthz Pod (no liveness yet) ----------------
echo "Creating healthz pod (no liveness probe yet)..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: healthz
  namespace: default
spec:
  containers:
    - name: web
      image: nginx
      ports:
        - containerPort: 80
EOF
echo

# ---------------- Q12: shop-api Deployment ----------------
echo "Creating shop-api deployment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop-api
  template:
    metadata:
      labels:
        app: shop-api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 8080
EOF
echo

# ---------------- Q14: audit-runner + wrong-sa (RBAC) ----------------
echo "Creating audit-runner with wrong-sa..."
kubectl get sa wrong-sa -n default >/dev/null 2>&1 || kubectl create sa wrong-sa -n default
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: audit-runner
  namespace: default
spec:
  serviceAccountName: wrong-sa
  containers:
    - name: kubectl
      image: bitnami/kubectl:latest
      command: ["/bin/sh","-c"]
      args:
        - |
          while true; do
            echo "Attempting: kubectl get pods --all-namespaces"
            kubectl get pods --all-namespaces || echo "Forbidden?"
            sleep 10
          done
EOF
echo

# ---------------- Q15–16: /opt/winter & cpu-load namespace ----------------
echo "Preparing /opt/winter and winter pod..."
# No sudo here so script doesn't break in environments without sudo;
# if mkdir fails, it won't stop the script.
mkdir -p /opt/winter 2>/dev/null || echo "WARN: could not create /opt/winter, create it manually if needed."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: winter
  namespace: default
spec:
  containers:
    - name: logger
      image: busybox
      command: ["/bin/sh","-c"]
      args:
        - |
          i=0
          while true; do
            echo "winter log line $i"
            i=$((i+1))
            sleep 5
          done
EOF
echo

echo "Creating CPU load pods in namespace cpu-load..."
kubectl apply -n cpu-load -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cpu-busy-1
spec:
  containers:
    - name: busy
      image: busybox
      command: ["/bin/sh","-c"]
      args:
        - |
          while true; do
            sha1sum /dev/urandom | head -c 1000 >/dev/null
          done
---
apiVersion: v1
kind: Pod
metadata:
  name: cpu-busy-2
spec:
  containers:
    - name: busy
      image: busybox
      command: ["/bin/sh","-c"]
      args:
        - |
          while true; do
            sha1sum /dev/urandom | head -c 1000 >/dev/null
          done
EOF
echo

# ---------------- Q17: video-api Deployment ----------------
echo "Creating video-api deployment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: video-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: video-api
  template:
    metadata:
      labels:
        app: video-api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 9090
EOF
echo

# ---------------- Q18: broken client-ingress manifest (file only) ----------------
echo "Writing broken client-ingress manifest to ${BASE_DIR}/client-ingress.yaml..."
cat > "${BASE_DIR}/client-ingress.yaml" <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: client-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: InvalidType
            backend:
              service:
                name: client-svc
                port:
                  number: 80
EOF
echo "NOTE: This manifest uses an invalid pathType on purpose. You'll apply and fix it during the exercise."
echo

# Also create client-svc + client-app for that ingress exercise
echo "Creating client-svc and client-app..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      containers:
        - name: web
          image: nginx
---
apiVersion: v1
kind: Service
metadata:
  name: client-svc
  namespace: default
spec:
  selector:
    app: client
  ports:
    - port: 80
      targetPort: 80
EOF
echo

# ---------------- Q19: syncer base deployment ----------------
echo "Creating syncer deployment (no securityContext yet)..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: syncer
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: syncer
  template:
    metadata:
      labels:
        app: syncer
    spec:
      containers:
        - name: sync
          image: nginx
EOF
echo

# ---------------- Q20: netpol-chain pods + networkpolicies ----------------
echo "Creating netpol-chain pods and NetworkPolicies..."
kubectl apply -n netpol-chain -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  labels:
    role: wrong-frontend
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  labels:
    role: wrong-backend
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  labels:
    role: wrong-db
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
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

# ---------------- Q22: dashboard deployment (paused) ----------------
echo "Creating paused dashboard deployment..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard
  namespace: default
spec:
  paused: true
  replicas: 2
  selector:
    matchLabels:
      app: dashboard
  template:
    metadata:
      labels:
        app: dashboard
    spec:
      containers:
        - name: web
          image: nginx:1.23
EOF
echo

# ---------------- Q24: hourly-report CronJob (misconfigured) ----------------
echo "Creating hourly-report CronJob with wrong restartPolicy/backoffLimit..."
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-report
  namespace: default
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      backoffLimit: 5
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: report
              image: busybox
              command: ["/bin/sh","-c"]
              args: ["echo hourly report; sleep 5"]
EOF
echo

# ---------------- Q25: broken-app manifest (file only) ----------------
echo "Writing broken deployment manifest to ${BASE_DIR}/broken-app.yaml..."
cat > "${BASE_DIR}/broken-app.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: something-else
  template:
    metadata:
      labels:
        app: fixed-app
    spec:
      containers:
        - name: web
          image: nginx
EOF
echo "NOTE: Selector/template labels intentionally mismatched. You'll fix & apply this during the exercise."
echo

echo "=== CKAD practice environment prep COMPLETE ==="
echo "Manifests written under: ${BASE_DIR}"
