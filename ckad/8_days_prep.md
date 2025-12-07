````md
# CKAD 8-Day Bootcamp – Labs, Questions & Solutions

This file is your **practice guide** for the 8-day CKAD plan.

Namespaces used:

- `day1-env`
- `day2-sec`
- `day3-svc`
- `day4-net`
- `day5-deploy`
- `day6-jobs`

> 💡 Before practicing, run:
>
> ```bash
> ./prepare-8day-labs.sh
> ```
>
> This creates all required namespaces and baseline objects.

---

# 🗓️ DAY 1 — Environment, Secrets, ConfigMaps

Namespace: **`day1-env`**

---

## 🔥 Q1.1 — Convert Hardcoded Env Vars to Secret (Deployment)

There is a Deployment `login-api` in `day1-env` with hardcoded env vars:

```yaml
env:
  - name: DB_USER
    value: "root"
  - name: DB_PASS
    value: "P@ssw0rd"
```
````

**Tasks:**

1. Create a Secret `db-credentials` in `day1-env` with keys `DB_USER=root` and `DB_PASS=P@ssw0rd`.
2. Update `login-api` so `DB_USER` and `DB_PASS` come from that Secret (use `valueFrom.secretKeyRef`).

### ✅ Solution 1.1

Create Secret:

```bash
kubectl create secret generic db-credentials \
  -n day1-env \
  --from-literal=DB_USER=root \
  --from-literal=DB_PASS=P@ssw0rd
```

Edit Deployment:

```bash
kubectl edit deploy login-api -n day1-env
```

Change env section:

```yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_USER
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_PASS
```

---

## 🔥 Q1.2 — ConfigMap for App Settings (envFrom)

You want `settings` like:

- `LOG_LEVEL=debug`
- `FEATURE_X_ENABLED=true`

**Tasks:**

1. Create ConfigMap `app-settings` in `day1-env` with those keys.
2. Update Deployment `login-api` so that **all keys** in `app-settings` are available as environment variables using `envFrom`.

### ✅ Solution 1.2

Create ConfigMap:

```bash
kubectl create configmap app-settings \
  -n day1-env \
  --from-literal=LOG_LEVEL=debug \
  --from-literal=FEATURE_X_ENABLED=true
```

Edit `login-api`:

```bash
kubectl edit deploy login-api -n day1-env
```

Under container spec, add:

```yaml
envFrom:
  - configMapRef:
      name: app-settings
```

You can leave the previous `env` section as is — both will be combined.

---

## 🔥 Q1.3 — Mount ConfigMap as Volume

Create a new Pod `cm-volume-pod` in `day1-env`:

- Image: `nginx`
- ConfigMap: `nginx-config` with a key `index.html: "<h1>CKAD</h1>"`
- Mount ConfigMap at `/usr/share/nginx/html`.

### ✅ Solution 1.3

Create ConfigMap (if not already):

```bash
kubectl create configmap nginx-config \
  -n day1-env \
  --from-literal=index.html="<h1>CKAD</h1>"
```

Pod manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cm-volume-pod
  namespace: day1-env
spec:
  volumes:
    - name: web-content
      configMap:
        name: nginx-config
  containers:
    - name: web
      image: nginx
      volumeMounts:
        - name: web-content
          mountPath: /usr/share/nginx/html
```

Apply:

```bash
kubectl apply -f cm-volume-pod.yaml
```

---

## 🔥 Q1.4 — Secret + ConfigMap Mixed Env

Create a Deployment `mix-api` in `day1-env`:

- Image: `nginx`
- Env:

  - `API_KEY` from Secret `api-secret`, key `API_KEY`
  - `API_ENV` from ConfigMap `api-config`, key `API_ENV`

Create the needed Secret and ConfigMap too.

### ✅ Solution 1.4

Secret:

```bash
kubectl create secret generic api-secret \
  -n day1-env \
  --from-literal=API_KEY=supersecret
```

ConfigMap:

```bash
kubectl create configmap api-config \
  -n day1-env \
  --from-literal=API_ENV=staging
```

Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mix-api
  namespace: day1-env
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mix-api
  template:
    metadata:
      labels:
        app: mix-api
    spec:
      containers:
        - name: app
          image: nginx
          env:
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: api-secret
                  key: API_KEY
            - name: API_ENV
              valueFrom:
                configMapKeyRef:
                  name: api-config
                  key: API_ENV
```

Apply:

```bash
kubectl apply -f mix-api.yaml
```

---

# 🗓️ DAY 2 — Security, Probes, Resource Limits, RBAC

Namespace: **`day2-sec`**

---

## 🔥 Q2.1 — Add Pod SecurityContext (runAsUser + NET_ADMIN)

In `day2-sec`, there is a Deployment `net-tool` with container `tool` and no security context.

**Task:**

- Set Pod-level `runAsUser` to `1000`.
- Add capability `NET_ADMIN` to container `tool`.

### ✅ Solution 2.1

```bash
kubectl edit deploy net-tool -n day2-sec
```

Change `spec.template.spec`:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsUser: 1000
      containers:
        - name: tool
          image: nginx
          securityContext:
            capabilities:
              add: ["NET_ADMIN"]
```

---

## 🔥 Q2.2 — Add Readiness + Liveness Probes

Deployment `pay-api` in `day2-sec` exposes container port `8080` but has **no probes**.

**Task:**

- Add readiness probe:

  - HTTP GET `/ready` on port `8080`
  - initialDelay: `5`

- Add liveness probe:

  - HTTP GET `/healthz` on port `8080`
  - initialDelay: `10`

### ✅ Solution 2.2

```bash
kubectl edit deploy pay-api -n day2-sec
```

Under container:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
```

---

## 🔥 Q2.3 — Add Resource Requests & Limits

Same `pay-api` Deployment needs:

- requests: `cpu=200m`, `memory=128Mi`
- limits: `cpu=500m`, `memory=256Mi`

### ✅ Solution 2.3

Edit `pay-api` again:

```yaml
resources:
  requests:
    cpu: "200m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "256Mi"
```

Placed under the container spec.

---

## 🔥 Q2.4 — ServiceAccount + Role + RoleBinding

There is a Pod `log-reader` in `day2-sec` that currently uses ServiceAccount `default` and fails when trying to `kubectl get pods`.

**Task:**

1. Create SA `reader-sa` in `day2-sec`.
2. Create Role `pod-reader` in `day2-sec` with verbs `get`, `list`, `watch` on resource `pods`.
3. Create RoleBinding `pod-reader-rb` binding `pod-reader` to `reader-sa`.
4. Patch Pod `log-reader` to use `reader-sa`.

### ✅ Solution 2.4

```bash
kubectl create sa reader-sa -n day2-sec

kubectl create role pod-reader \
  --verb=get --verb=list --verb=watch \
  --resource=pods \
  -n day2-sec

kubectl create rolebinding pod-reader-rb \
  --role=pod-reader \
  --serviceaccount=day2-sec:reader-sa \
  -n day2-sec

kubectl patch pod log-reader -n day2-sec \
  -p '{"spec":{"serviceAccountName":"reader-sa"}}'
```

---

# 🗓️ DAY 3 — Services (ClusterIP, NodePort, ExternalName)

Namespace: **`day3-svc`**

The script creates 3 Deployments:

- `web-frontend` (`app=web-frontend`, port 80)
- `api-backend` (`app=api-backend`, port 3000)
- `db-mysql` (external DB, we simulate with hostname)

---

## 🔥 Q3.1 — Expose Frontend as ClusterIP

Create a Service:

- name: `web-frontend-svc`
- type: `ClusterIP`
- selector: `app=web-frontend`
- port: `80` → targetPort: `80`

### ✅ Solution 3.1

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-frontend-svc
  namespace: day3-svc
spec:
  type: ClusterIP
  selector:
    app: web-frontend
  ports:
    - port: 80
      targetPort: 80
```

Apply:

```bash
kubectl apply -f web-frontend-svc.yaml
```

---

## 🔥 Q3.2 — Expose Backend as NodePort

Create a Service:

- name: `api-backend-svc`
- type: `NodePort`
- selector: `app=api-backend`
- port: `3000`
- nodePort: any valid (e.g. `32080`)

### ✅ Solution 3.2

```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-backend-svc
  namespace: day3-svc
spec:
  type: NodePort
  selector:
    app: api-backend
  ports:
    - port: 3000
      targetPort: 3000
      nodePort: 32080
```

Apply:

```bash
kubectl apply -f api-backend-svc.yaml
```

---

## 🔥 Q3.3 — ExternalName Service for DB

Simulate external DB `db.example.internal`.

Create a Service:

- name: `mysql-ext`
- type: `ExternalName`
- externalName: `db.example.internal`

### ✅ Solution 3.3

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-ext
  namespace: day3-svc
spec:
  type: ExternalName
  externalName: db.example.internal
```

Apply:

```bash
kubectl apply -f mysql-ext.yaml
```

---

## 🔥 Q3.4 — Fix Misconfigured Selector

There is a Service `broken-api-svc` with selector `tier=api`, but Deployment `api-backend` is labeled `app=api-backend`.

**Task:** Fix the Service selector only.

### ✅ Solution 3.4

```bash
kubectl edit svc broken-api-svc -n day3-svc
```

Change:

```yaml
selector:
  tier: api
```

to:

```yaml
selector:
  app: api-backend
```

---

# 🗓️ DAY 4 — Ingress + NetworkPolicies

Namespace: **`day4-net`**

Script provisions:

- Deployments: `shop-frontend`, `shop-backend`
- Services: `shop-frontend-svc`, `shop-backend-svc`
- Some NetworkPolicies and a broken Ingress.

---

## 🔥 Q4.1 — Fix Ingress Backend

Ingress `shop-ing` exists but:

- Points to wrong Service name or port.

**Task:** Fix `shop-ing` in `day4-net` so:

- Host: `shop.example.com`
- Path `/`
- Backend: Service `shop-frontend-svc`, port `80`

### ✅ Solution 4.1

```bash
kubectl edit ingress shop-ing -n day4-net
```

Ensure:

```yaml
spec:
  rules:
    - host: shop.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: shop-frontend-svc
                port:
                  number: 80
```

---

## 🔥 Q4.2 — Create API Ingress

Create a new Ingress `shop-api-ing` in `day4-net`:

- Host: `api.shop.example.com`
- Path `/api`
- Backend: `shop-backend-svc:3000`

### ✅ Solution 4.2

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: shop-api-ing
  namespace: day4-net
spec:
  rules:
    - host: api.shop.example.com
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: shop-backend-svc
                port:
                  number: 3000
```

Apply:

```bash
kubectl apply -f shop-api-ing.yaml
```

---

## 🔥 Q4.3 — NetworkPolicy Label Fix

Pods:

- `frontend` (labels wrong)
- `backend` (labels wrong)
- `db` (labels wrong)

NetworkPolicies expect:

- `frontend`: `role=frontend`
- `backend`: `role=backend`
- `db`: `role=db`

**Task:** Fix Pod labels (in `day4-net`) to match these roles; do NOT modify NetworkPolicies.

### ✅ Solution 4.3

```bash
kubectl label pod frontend role=frontend -n day4-net --overwrite
kubectl label pod backend  role=backend  -n day4-net --overwrite
kubectl label pod db       role=db       -n day4-net --overwrite
```

---

## 🔥 Q4.4 — Auth Pod NP Selectors

NetworkPolicies:

- `allow-auth-ingress`
- `allow-auth-egress`

Both expect Pods with:

- `role=auth`, `env=prod`

Pod `auth` currently has wrong labels.

**Task:** Update `auth` Pod labels accordingly.

### ✅ Solution 4.4

```bash
kubectl label pod auth role=auth env=prod -n day4-net --overwrite
```

---

# 🗓️ DAY 5 — Deployments, Rollouts, Rollbacks

Namespace: **`day5-deploy`**

Script sets up Deployments:

- `orders-api` (image: `nginx:1.25`)
- `users-api` (image: `nginx:1.25`)
- `canary-api-stable` (image: `nginx:1.25`)

---

## 🔥 Q5.1 — Scale Deployment

In `day5-deploy`, scale `orders-api` replicas to `4`.

### ✅ Solution 5.1

```bash
kubectl scale deploy orders-api -n day5-deploy --replicas=4
kubectl get deploy orders-api -n day5-deploy
```

---

## 🔥 Q5.2 — Rolling Update (set image) + Check Status

Update `users-api` image to `nginx:1.27` and wait for rollout success.

### ✅ Solution 5.2

```bash
kubectl set image deploy/users-api users-api=nginx:1.27 -n day5-deploy
kubectl rollout status deploy/users-api -n day5-deploy
```

(Use actual container name if different.)

---

## 🔥 Q5.3 — Rollback to Previous Revision

You accidentally set `users-api` to a bad image `nginx:bad-tag`.

**Task:**

- Perform a rollback to previous revision.
- Confirm Deployment is using `nginx:1.27` again.

### ✅ Solution 5.3

```bash
kubectl set image deploy/users-api users-api=nginx:bad-tag -n day5-deploy
kubectl rollout status deploy/users-api -n day5-deploy || true

kubectl rollout undo deploy/users-api -n day5-deploy
kubectl get deploy users-api -n day5-deploy -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 🔥 Q5.4 — Pause, Update, Resume

Deployment `orders-api` currently runs `nginx:1.25`.

**Task:**

1. Pause its rollout.
2. Change image to `nginx:1.27`.
3. Resume rollout.
4. Check rollout status.

### ✅ Solution 5.4

```bash
kubectl rollout pause deploy/orders-api -n day5-deploy

kubectl set image deploy/orders-api orders-api=nginx:1.27 -n day5-deploy

kubectl rollout resume deploy/orders-api -n day5-deploy
kubectl rollout status deploy/orders-api -n day5-deploy
```

---

## 🔥 Q5.5 — Canary Deployment

`canary-api-stable` exists with:

- labels: `app=canary-api`, `version=v1`
- replicas: 4

**Task:** Create `canary-api-v2` in `day5-deploy`:

- labels: `app=canary-api`, `version=v2`
- replicas: 1
- image: `nginx:1.27`

Service `canary-api-svc` selects `app=canary-api`.

### ✅ Solution 5.5

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: canary-api-v2
  namespace: day5-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: canary-api
      version: v2
  template:
    metadata:
      labels:
        app: canary-api
        version: v2
    spec:
      containers:
        - name: api
          image: nginx:1.27
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f canary-api-v2.yaml
```

Service `canary-api-svc` will now see both v1 and v2.

---

# 🗓️ DAY 6 — Jobs, CronJobs, InitContainers, Volume Tricks

Namespace: **`day6-jobs`**

---

## 🔥 Q6.1 — One-Time Job

Create a Job `hello-job` in `day6-jobs`:

- image: `busybox`
- command: `echo hello-ckad`

### ✅ Solution 6.1

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello-job
  namespace: day6-jobs
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: hello
          image: busybox
          command: ["sh", "-c", "echo hello-ckad"]
```

Apply:

```bash
kubectl apply -f hello-job.yaml
```

---

## 🔥 Q6.2 — CronJob Every 3 Minutes

Create CronJob `ping-cron`:

- schedule: `"*/3 * * * *"`
- image: `busybox`
- command: `date; echo ping`

### ✅ Solution 6.2

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ping-cron
  namespace: day6-jobs
spec:
  schedule: "*/3 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: ping
              image: busybox
              command: ["sh", "-c", "date; echo ping"]
```

Apply:

```bash
kubectl apply -f ping-cron.yaml
```

---

## 🔥 Q6.3 — CronJob with Completions & BackoffLimit

Create CronJob `batch-workers`:

- schedule: `"*/5 * * * *"`
- completions: `5`
- parallelism: `2`
- backoffLimit: `4`
- image: `busybox`
- command: `echo processing && sleep 2`

### ✅ Solution 6.3

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: batch-workers
  namespace: day6-jobs
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      completions: 5
      parallelism: 2
      backoffLimit: 4
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: worker
              image: busybox
              command: ["sh", "-c", "echo processing && sleep 2"]
```

Apply:

```bash
kubectl apply -f batch-workers.yaml
```

---

## 🔥 Q6.4 — InitContainer + shared emptyDir

Create Pod `init-script-pod` in `day6-jobs`:

- `emptyDir` volume `scripts`
- initContainer writes `/scripts/start.sh` with content `echo app-started`
- main container runs `sh /scripts/start.sh`

### ✅ Solution 6.4

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-script-pod
  namespace: day6-jobs
spec:
  volumes:
    - name: scripts
      emptyDir: {}
  initContainers:
    - name: init
      image: busybox
      command:
        - sh
        - -c
        - "echo 'echo app-started' > /scripts/start.sh && chmod +x /scripts/start.sh"
      volumeMounts:
        - name: scripts
          mountPath: /scripts
  containers:
    - name: app
      image: busybox
      command: ["sh", "-c", "sh /scripts/start.sh && sleep 3600"]
      volumeMounts:
        - name: scripts
          mountPath: /scripts
```

Apply:

```bash
kubectl apply -f init-script-pod.yaml
```

---

# 🗓️ DAY 7 & 8 — Full Simulated Exams

For Days 7 and 8:

- Use the **20-question CKAD Master Practice** we already built:

  - `CKAD-Master-Practice.md`
  - `prepare-ckad-practice.sh`
  - `check-ckad-practice.sh`

**Day 7:**

- Run full exam once, untimed.
- Fix all failed questions using the checker.

**Day 8:**

- Run full exam again, timed (e.g. 60–75 minutes).
- Aim for **80–90%+**.

This mirrors the real CKAD pressure and question style.

---

````

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
````

---

If you want, next we can add a **per-day checker script** (like we did for the 20-question exam) so you can run, for example:

```bash
./check-day1.sh
./check-day2.sh
...
```

and get instant PASS/FAIL per question + percentage for that day.
