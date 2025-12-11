#!/usr/bin/env bash
set -euo pipefail

echo "=== CKAD practice environment prep ==="

# -------------------------
# Namespaces
# -------------------------
for ns in meta dev cachelayer netpol-chain cpu-load production; do
  if ! kubectl get ns "$ns" >/dev/null 2>&1; then
    echo "Creating namespace: $ns"
    kubectl create ns "$ns"
  else
    echo "Namespace $ns already exists"
  fi
done

# -------------------------
# Q1 – billing-api Deployment with hardcoded env vars
# -------------------------
echo "Creating Deployment billing-api (hardcoded env vars)..."
kubectl apply -f - <<'EOF'
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
        - name: billing
          image: nginx
          env:
            - name: DB_USER
              value: "admin"
            - name: DB_PASS
              value: "SuperSecret123"
EOF

# -------------------------
# Q2 – Broken Ingress store-ingress + service / deployment
# -------------------------
echo "Creating store deployment, service and broken ingress..."
kubectl apply -f - <<'EOF'
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
        - name: store
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
# Broken ingress: wrong service name, wrong port, invalid/legacy pathType
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: store-ingress
  namespace: default
spec:
  rules:
    - http:
        paths:
          - path: /shop
            pathType: Exact   # not what we want for the question
            backend:
              service:
                name: wrong-svc   # wrong on purpose
                port:
                  number: 80      # wrong on purpose
EOF

# -------------------------
# Q3 – internal-api deployment + service (no ingress yet)
# -------------------------
echo "Creating internal-api deployment and service..."
kubectl apply -f - <<'EOF'
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

# -------------------------
# Q4 – RBAC problem on dev-deployment in namespace meta
# -------------------------
echo "Creating dev-deployment in namespace meta (RBAC issue)..."
kubectl apply -f - <<'EOF'
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
      serviceAccountName: default   # no special permissions
      containers:
        - name: api-client
          image: bitnami/kubectl:latest
          command: ["/bin/sh","-c"]
          args:
            - |
              while true; do
                echo "Trying to list deployments in meta..."
                kubectl get deployments.apps -n meta || true
                sleep 30
              done
EOF

# -------------------------
# Q5 – startup-pod missing script (no init container yet)
# -------------------------
echo "Creating broken startup-pod (missing /app/start.sh)..."
kubectl apply -f - <<'EOF'
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

# -------------------------
# Q6 – Dockerfile at /root/api-app
# -------------------------
echo "Preparing /root/api-app with sample Dockerfile..."
mkdir -p /root/api-app
cat >/root/api-app/Dockerfile <<'EOF'
FROM nginx:latest
RUN echo "CKAD practice image" > /usr/share/nginx/html/index.html
EOF

# -------------------------
# Q7 – Namespace dev only (you will add pod + quota)
# -------------------------
echo "Namespace dev ready for resource Quota and Pod question."

# -------------------------
# Q8 – /root/old.yaml with deprecated Deployment config
# -------------------------
echo "Writing deprecated deployment manifest to /root/old.yaml..."
cat >/root/old.yaml <<'EOF'
apiVersion: apps/v1beta1
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
      maxSurge: 200%        # intentionally invalid
      maxUnavailable: -1    # intentionally invalid
EOF

# -------------------------
# Q9 – app-stable deployment + app-svc service
# -------------------------
echo "Creating app-stable deployment and app-svc..."
kubectl apply -f - <<'EOF'
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

# -------------------------
# Q10 – web-app deployment + misconfigured web-app-svc
# -------------------------
echo "Creating web-app and broken web-app-svc..."
kubectl apply -f - <<'EOF'
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
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-svc
  namespace: default
spec:
  selector:
    app: wronglabel   # intentionally wrong
  ports:
    - port: 80
      targetPort: 80
EOF

# -------------------------
# Q11 – healthz pod without liveness probe
# -------------------------
echo "Creating healthz pod (no liveness probe yet)..."
kubectl apply -f - <<'EOF'
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

# -------------------------
# Q12 – shop-api deployment
# -------------------------
echo "Creating shop-api deployment..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shop-api
  namespace: default
spec:
  replicas: 2
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

# -------------------------
# Q14 – audit-runner pod with wrong service account
# -------------------------
echo "Creating audit-runner with wrong-sa..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: wrong-sa
  namespace: default
---
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
            kubectl get pods --all-namespaces || true
            sleep 30
          done
EOF

# -------------------------
# Q15 & Q16 – winter.yaml + cpu-load namespace pods
# -------------------------
echo "Preparing /opt/winter and winter pod..."
mkdir -p /opt/winter
cat >/opt/winter/winter.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: winter
  namespace: default
spec:
  containers:
    - name: main
      image: busybox
      command: ["/bin/sh","-c"]
      args: ["while true; do echo winter running; sleep 10; done"]
EOF

kubectl apply -f /opt/winter/winter.yaml

echo "Creating CPU load pods in namespace cpu-load..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: cpu-busy-1
  namespace: cpu-load
spec:
  containers:
    - name: load
      image: busybox
      command: ["/bin/sh","-c"]
      args: ["while true; do :; done"]
---
apiVersion: v1
kind: Pod
metadata:
  name: cpu-busy-2
  namespace: cpu-load
spec:
  containers:
    - name: load
      image: busybox
      command: ["/bin/sh","-c"]
      args: ["while true; do :; done"]
EOF

# -------------------------
# Q17 – video-api deployment
# -------------------------
echo "Creating video-api deployment..."
kubectl apply -f - <<'EOF'
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

# -------------------------
# Q18 – client-ingress: write broken manifest to disk, don't apply
# -------------------------
echo "Creating client-svc and client-app (Ingress manifest will be on disk only)..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: client-svc
  namespace: default
spec:
  selector:
    app: client-app
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client-app
  template:
    metadata:
      labels:
        app: client-app
    spec:
      containers:
        - name: web
          image: nginx
          ports:
            - containerPort: 80
EOF

echo "Writing broken Ingress manifest for client-ingress to /root/client-ingress.yaml..."
cat >/root/client-ingress.yaml <<'EOF'
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
            pathType: InvalidType   # intentionally invalid
            backend:
              service:
                name: client-svc
                port:
                  number: 80
EOF


# -------------------------
# Q19 – syncer deployment (no securityContext yet)
# -------------------------
echo "Creating syncer deployment..."
kubectl apply -f - <<'EOF'
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

# -------------------------
# Q20 – namespace cachelayer (you create redis32 pod)
# -------------------------
echo "Namespace cachelayer is ready for redis32 pod."

# -------------------------
# Q21 – netpol-chain: pods + netpols with mismatched labels
# -------------------------
echo "Creating netpol-chain pods and network policies..."
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: frontend
  namespace: netpol-chain
  labels:
    role: wrong-frontend   # intentionally wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: backend
  namespace: netpol-chain
  labels:
    role: wrong-backend    # intentionally wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: v1
kind: Pod
metadata:
  name: database
  namespace: netpol-chain
  labels:
    role: wrong-db         # intentionally wrong
spec:
  containers:
    - name: app
      image: nginx
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: netpol-chain
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: netpol-chain
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
  namespace: netpol-chain
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

# -------------------------
# Q22 – dashboard deployment paused rollout
# -------------------------
echo "Creating dashboard deployment and pausing rollout..."
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dashboard
  namespace: default
spec:
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

kubectl rollout pause deployment/dashboard

# -------------------------
# Q24 – hourly-report CronJob with bad restart policy
# -------------------------
echo "Creating misconfigured hourly-report CronJob..."
kubectl apply -f - <<'EOF'
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hourly-report
  namespace: default
spec:
  schedule: "0 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure   # you will adjust this
          containers:
            - name: report
              image: busybox
              command: ["/bin/sh","-c"]
              args: ["echo hourly report; sleep 5"]
EOF

# -------------------------
# Q25 – broken-app.yaml with mismatched selector/labels
# -------------------------
echo "Writing broken app manifest to /root/broken-app.yaml..."
cat >/root/broken-app.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: broken   # does NOT match template labels
  template:
    metadata:
      labels:
        app: different-label   # mismatch on purpose
    spec:
      containers:
        - name: web
          image: nginx
EOF

echo "=== CKAD practice environment is ready. ==="
echo "You can now start working through the 25 questions."
