
---

## 2️⃣ Environment Setup Script: `prepare-8day-labs.sh`

This sets up all namespaces and base/broken objects used in Days 1–6.

```bash
#!/bin/bash
set -euo pipefail

echo "=== CKAD 8-Day Labs Environment Setup ==="

# Namespaces
for ns in day1-env day2-sec day3-svc day4-net day5-deploy day6-jobs; do
  echo "[*] Creating namespace: $ns"
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ---------------- DAY 1: login-api with hardcoded env ----------------
echo "[*] Day1: Creating login-api deployment with hardcoded env in day1-env..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: login-api
  namespace: day1-env
spec:
  replicas: 1
  selector:
    matchLabels:
      app: login-api
  template:
    metadata:
      labels:
        app: login-api
    spec:
      containers:
        - name: api
          image: nginx
          env:
            - name: DB_USER
              value: "root"
            - name: DB_PASS
              value: "P@ssw0rd"
EOF

# ---------------- DAY 2: Security/Probes/RBAC ----------------
echo "[*] Day2: Creating net-tool, pay-api, log-reader in day2-sec..."

# net-tool for SecurityContext
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: net-tool
  namespace: day2-sec
spec:
  replicas: 1
  selector:
    matchLabels:
      app: net-tool
  template:
    metadata:
      labels:
        app: net-tool
    spec:
      containers:
        - name: tool
          image: nginx
EOF

# pay-api without probes/resources
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pay-api
  namespace: day2-sec
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pay-api
  template:
    metadata:
      labels:
        app: pay-api
    spec:
      containers:
        - name: pay-api
          image: nginx
          ports:
            - containerPort: 8080
EOF

# log-reader pod using default SA; will try to list pods
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: log-reader
  namespace: day2-sec
spec:
  serviceAccountName: default
  containers:
    - name: reader
      image: bitnami/kubectl:latest
      command:
        - sh
        - -c
        - "kubectl get pods -A && sleep 3600"
EOF

# ---------------- DAY 3: Services lab ----------------
echo "[*] Day3: Creating web-frontend, api-backend, broken-api-svc in day3-svc..."

# web-frontend deployment
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-frontend
  namespace: day3-svc
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-frontend
  template:
    metadata:
      labels:
        app: web-frontend
    spec:
      containers:
        - name: web
          image: nginx
          ports:
            - containerPort: 80
EOF

# api-backend deployment
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
  namespace: day3-svc
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-backend
  template:
    metadata:
      labels:
        app: api-backend
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 3000
EOF

# broken service with wrong selector
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: broken-api-svc
  namespace: day3-svc
spec:
  selector:
    tier: api   # wrong, to be fixed
  ports:
    - port: 3000
      targetPort: 3000
EOF

# ---------------- DAY 4: Ingress + Netpol lab ----------------
echo "[*] Day4: Creating shop deployments, services, ingress, and netpol pods in day4-net..."

# shop-frontend & shop-backend deployments + services
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-frontend
  namespace: day4-net
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop-frontend
  template:
    metadata:
      labels:
        app: shop-frontend
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
  name: shop-frontend-svc
  namespace: day4-net
spec:
  selector:
    app: shop-frontend
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-backend
  namespace: day4-net
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shop-backend
  template:
    metadata:
      labels:
        app: shop-backend
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
  name: shop-backend-svc
  namespace: day4-net
spec:
  selector:
    app: shop-backend
  ports:
    - port: 3000
      targetPort: 3000
EOF

# broken ingress shop-ing
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-ing
  namespace: day4-net
spec:
  rules:
    - host: wrong.example.com    # to be fixed
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wrong-svc  # to be fixed -> shop-frontend-svc
                port:
                  number: 8080  # to be fixed -> 80
EOF

# netpol pods: frontend, backend, db, auth
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: day4-net
  labels:
    role: front-wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: day4-net
  labels:
    role: back-wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: db
  namespace: day4-net
  labels:
    role: db-wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: auth
  namespace: day4-net
  labels:
    role: wrong-auth
    env: dev
spec:
  containers:
    - name: app
      image: nginx
EOF

# Example NetworkPolicies that expect specific labels
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: day4-net
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
  namespace: day4-net
spec:
  podSelector:
    matchLabels:
      role: db
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: backend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-auth-ingress
  namespace: day4-net
spec:
  podSelector:
    matchLabels:
      role: auth
      env: prod
  ingress:
    - from:
        - podSelector:
            matchLabels:
              role: frontend
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-auth-egress
  namespace: day4-net
spec:
  podSelector:
    matchLabels:
      role: auth
      env: prod
  egress:
    - to:
        - podSelector:
            matchLabels:
              role: db
EOF

# ---------------- DAY 5: Deployments lab ----------------
echo "[*] Day5: Creating orders-api, users-api, canary-api-stable in day5-deploy..."

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders-api
  namespace: day5-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: orders-api
  template:
    metadata:
      labels:
        app: orders-api
    spec:
      containers:
        - name: orders-api
          image: nginx:1.25
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: users-api
  namespace: day5-deploy
spec:
  replicas: 2
  selector:
    matchLabels:
      app: users-api
  template:
    metadata:
      labels:
        app: users-api
    spec:
      containers:
        - name: users-api
          image: nginx:1.25
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-api-stable
  namespace: day5-deploy
spec:
  replicas: 4
  selector:
    matchLabels:
      app: canary-api
      version: v1
  template:
    metadata:
      labels:
        app: canary-api
        version: v1
    spec:
      containers:
        - name: api
          image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: canary-api-svc
  namespace: day5-deploy
spec:
  selector:
    app: canary-api
  ports:
    - port: 80
      targetPort: 80
EOF

# ---------------- DAY 6: Jobs & CronJobs base ----------------
echo "[*] Day6: Namespace day6-jobs ready (no base objects required)."

echo "=== 8-Day Labs Environment Ready ==="
