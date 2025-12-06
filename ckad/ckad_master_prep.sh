#!/bin/bash
set -euo pipefail

echo "=== CKAD Master Practice Environment Setup ==="

# ---------------------------------------------------------
# Namespaces
# ---------------------------------------------------------
echo "[*] Creating namespaces..."
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace netpol-lab --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace rbac-lab --dry-run=client -o yaml | kubectl apply -f -

# ---------------------------------------------------------
# Q1: db-api Deployment with hard-coded env in 'prod'
# ---------------------------------------------------------
echo "[*] Setting up Q1: db-api deployment with hard-coded env..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-api
  namespace: prod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db-api
  template:
    metadata:
      labels:
        app: db-api
    spec:
      containers:
        - name: db-api
          image: nginx
          env:
            - name: USER
              value: "root"
            - name: PASSWORD
              value: "admin123"
EOF

# ---------------------------------------------------------
# Q2: Ingress with wrong backend service name and port
# ---------------------------------------------------------
echo "[*] Setting up Q2: web-svc + bad ingress to fix..."
# Service + Deployment that SHOULD be targeted by Ingress
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-svc
  namespace: default
spec:
  selector:
    app: web
  ports:
    - port: 8080
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy-main
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx
          ports:
            - containerPort: 80
EOF

# Incorrect ingress to fix (wrong service name/port)
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-bad-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wrong-svc-name   # to be fixed to web-svc
                port:
                  number: 80           # to be fixed to 8080
EOF

# ---------------------------------------------------------
# Q3: api-svc Service (Ingress to be created by you)
# ---------------------------------------------------------
echo "[*] Setting up Q3: api-svc backend for Ingress..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-svc
  namespace: default
spec:
  selector:
    app: api
  ports:
    - port: 3000
      targetPort: 3000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx
          ports:
            - containerPort: 3000
EOF

# ---------------------------------------------------------
# Q4: NetworkPolicy lab (netpol-lab ns, 4 NPs + 3 Pods)
# ---------------------------------------------------------
echo "[*] Setting up Q4: netpol lab with 4 NetworkPolicies and 3 Pods..."
# Simple pods
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-lab
  labels:
    role: frontend-initial   # intentionally wrong, to be fixed
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: netpol-lab
  labels:
    role: backend-initial    # intentionally wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  namespace: netpol-lab
  labels:
    role: db-initial         # intentionally wrong
spec:
  containers:
    - name: app
      image: nginx
EOF

# A few example NetworkPolicies (you'll align labels to these)
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: netpol-lab
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
  namespace: netpol-lab
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
  name: deny-all
  namespace: netpol-lab
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-http
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      role: frontend
  ingress:
    - ports:
        - port: 80
EOF

# ---------------------------------------------------------
# Q6: Docker build context in /root/app
# ---------------------------------------------------------
echo "[*] Setting up Q6: /root/app Docker build context..."
mkdir -p /root/app
cat <<'EOF' >/root/app/Dockerfile
FROM nginx:alpine
RUN echo '<h1>Tool v2</h1>' > /usr/share/nginx/html/index.html
EOF

# ---------------------------------------------------------
# Q7: Canary - stable app-stable + Service
# ---------------------------------------------------------
echo "[*] Setting up Q7: app-stable deployment and Service..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-stable
  namespace: default
spec:
  replicas: 4
  selector:
    matchLabels:
      app: app
      version: v1
  template:
    metadata:
      labels:
        app: app
        version: v1
    spec:
      containers:
        - name: app
          image: nginx
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: default
spec:
  selector:
    app: app
  ports:
    - port: 80
      targetPort: 80
EOF

# ---------------------------------------------------------
# Q8: Service with wrong selector
# ---------------------------------------------------------
echo "[*] Setting up Q8: Service with wrong selector..."
# Correct deployment for reference
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: nginx
EOF

# Wrong selector Service
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: default
spec:
  selector:
    tier: web     # to be fixed to app: web
  ports:
    - port: 80
      targetPort: 80
EOF

# ---------------------------------------------------------
# Q11: web-deploy for SecurityContext
# ---------------------------------------------------------
echo "[*] Setting up Q11: web-deploy without securityContext..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deploy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-sec
  template:
    metadata:
      labels:
        app: web-sec
    spec:
      containers:
        - name: web
          image: nginx
EOF

# ---------------------------------------------------------
# Q12: RBAC lab - audit-pod in rbac-lab namespace with wrong SA
# ---------------------------------------------------------
echo "[*] Setting up Q12: RBAC lab with audit-pod and wrong SA..."
# A service account that has NO extra permissions
kubectl create sa wrong-sa -n rbac-lab --dry-run=client -o yaml | kubectl apply -f -

# Pod that will try to list pods and get forbidden logs
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: audit-pod
  namespace: rbac-lab
spec:
  serviceAccountName: wrong-sa   # to be replaced with audit-sa by you
  containers:
    - name: audit
      image: bitnami/kubectl:latest
      command:
        - sh
        - -c
        - "kubectl get pods --all-namespaces && sleep 3600"
EOF

# ---------------------------------------------------------
# Q13: accounts-api deployment (for readinessProbe)
# ---------------------------------------------------------
echo "[*] Setting up Q13: accounts-api deployment..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: accounts-api
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: accounts-api
  template:
    metadata:
      labels:
        app: accounts-api
    spec:
      containers:
        - name: accounts
          image: nginx
          ports:
            - containerPort: 8080
EOF

# ---------------------------------------------------------
# Q14: livecheck pod (for livenessProbe)
# ---------------------------------------------------------
echo "[*] Setting up Q14: livecheck pod..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: livecheck
  namespace: default
spec:
  containers:
    - name: app
      image: nginx
      ports:
        - containerPort: 80
EOF

# ---------------------------------------------------------
# Q15: payments deployment with 2 revisions (for rollback)
# ---------------------------------------------------------
echo "[*] Setting up Q15: payments deployment with history..."
# First revision (v1)
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payments
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: payments
  template:
    metadata:
      labels:
        app: payments
    spec:
      containers:
        - name: payments
          image: nginx:1.25
EOF
# Update to a "bad" image to create second revision
kubectl set image deploy/payments payments=nginx:bad-tag -n default || true

# ---------------------------------------------------------
# Q16: old.yaml file with deprecated apiVersion and invalid maxSurge
# ---------------------------------------------------------
echo "[*] Creating /root/old.yaml for Q16..."
cat <<'EOF' >/root/old.yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: old-deploy
spec:
  strategy:
    rollingUpdate:
      maxSurge: "invalid"
  template:
    metadata:
      labels:
        app: old
    spec:
      containers:
        - name: old
          image: nginx
EOF

# ---------------------------------------------------------
# Q17: broken-init pod that fails due to missing /app/start.sh
# ---------------------------------------------------------
echo "[*] Setting up Q17: broken-init pod..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-init
  namespace: default
spec:
  containers:
    - name: app
      image: busybox
      command: ["/app/start.sh"]
      args: []
EOF

# ---------------------------------------------------------
# Q18: NetworkPolicies allow-auth-ingress & allow-db-egress + auth pod
# ---------------------------------------------------------
echo "[*] Setting up Q18: auth pod + NPs allow-auth-ingress / allow-db-egress..."
# Auth pod with wrong labels
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: auth
  namespace: netpol-lab
  labels:
    role: wrong-auth
    env: dev
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: db
  namespace: netpol-lab
  labels:
    role: db
    env: prod
spec:
  containers:
    - name: db
      image: nginx
EOF

# NetworkPolicies that expect certain labels
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-auth-ingress
  namespace: netpol-lab
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
  name: allow-db-egress
  namespace: netpol-lab
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
              env: prod
EOF

# ---------------------------------------------------------
# Q19: Ingress with invalid pathType
# ---------------------------------------------------------
echo "[*] Setting up Q19: Ingress with invalid pathType..."
# Backend svc
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: path-test-svc
  namespace: default
spec:
  selector:
    app: path-test
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: path-test-deploy
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: path-test
  template:
    metadata:
      labels:
        app: path-test
    spec:
      containers:
        - name: app
          image: nginx
          ports:
            - containerPort: 80
EOF

# Bad ingress
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bad-path-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Exacttt   # invalid; to be fixed
            backend:
              service:
                name: path-test-svc
                port:
                  number: 80
EOF

# ---------------------------------------------------------
# Q20: backend deployment for pause/update/resume
# ---------------------------------------------------------
echo "[*] Setting up Q20: backend deployment..."
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: nginx:1.25
EOF

echo "=== Environment ready. Use your CKAD practice questions file and start solving! ==="
