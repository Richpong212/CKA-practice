# ⭐ **THE CKAD MASTER PRACTICE EXAM (20 QUESTIONS + ANSWERS)**

Everything here is modeled on actual CKAD exam patterns from 2024–2025.

---

## 🔥 **QUESTION 1 — Convert Env Vars to Secret (Classic)**

You have Deployment `db-api` in namespace `prod`:

```yaml
env:
  - name: USER
    value: "root"
  - name: PASSWORD
    value: "admin123"
```

Task:

1. Create Secret `db-credentials` with these values.
2. Update Deployment to load env vars from the secret (individual envs, not envFrom).

### ✅ Answer 1 — Env vars → Secret

**Create Secret:**

```bash
kubectl create secret generic db-credentials \
  -n prod \
  --from-literal=USER=root \
  --from-literal=PASSWORD=admin123
```

**Edit Deployment:**

```bash
kubectl edit deploy db-api -n prod
```

Change `env` to:

```yaml
env:
  - name: USER
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: USER
  - name: PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: PASSWORD
```

**Why:** CKAD loves this pattern: hard-coded env → Secret → `valueFrom.secretKeyRef`.

---

## 🔥 **QUESTION 2 — Ingress Fix (Wrong Service Name / Port)**

An Ingress is created but does not route traffic.

You inspect it and find:

- Incorrect Service name
- Incorrect Service port

Fix both so the Ingress points correctly to Service `web-svc` on port 8080, host not required.

### ✅ Answer 2 — Ingress: wrong Service name/port

Edit ingress:

```bash
kubectl edit ingress <ingress-name> -n <ns>
```

Fix backend:

```yaml
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc
                port:
                  number: 8080
```

**Why:** In `networking.k8s.io/v1`, backend is nested under `service.name` and `service.port.number`.

---

## 🔥 **QUESTION 3 — Ingress With Hostname**

Create an Ingress:

- name: `api-ing`
- path `/`
- backend service: `api-svc:3000`
- host: `api.example.com`

### ✅ Answer 3 — Ingress with hostname

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ing
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-svc
                port:
                  number: 3000
```

Apply:

```bash
kubectl apply -f api-ing.yaml
```

**Why:** This is the standard Ingress structure in 1.19+ (and CKAD).

---

## 🔥 **QUESTION 4 — NetworkPolicy Label Assignment**

You have **4 existing NetworkPolicies**.
Three Pods exist: `frontend`, `backend`, and `database`.

You want `frontend` → `backend` → `database` to communicate in a chain.
Do **NOT** edit any NetworkPolicies.
Update the Pods with the correct labels matching the `podSelector` fields inside the relevant NP definitions.

### ✅ Answer 4 — NetworkPolicy: use correct labels on Pods

1. Inspect the policies:

```bash
kubectl get netpol -n <ns>
kubectl describe netpol <netpol-name> -n <ns>
```

Look for:

```yaml
podSelector:
  matchLabels:
    role: backend
```

etc.

2. Label Pods to match selectors (example):

```bash
kubectl label pod frontend role=frontend -n <ns>
kubectl label pod backend role=backend -n <ns>
kubectl label pod database role=database -n <ns>
```

(Use the exact keys/values from each policy’s `podSelector` / `namespaceSelector`.)

**Why:** NetworkPolicy matches **only** by labels; to “use the correct NP”, you fix Pod labels, not the NP.

---

## 🔥 **QUESTION 5 — Resource Limits + Quota**

Create a Pod `heavy-pod` in ns `dev` with:

- requests: cpu 200m, memory 128Mi
- limits: cpu 500m, memory 256Mi

Then create ResourceQuota `dev-quota`:

- limit total pods to 10
- total cpu requests: 2 cores
- total mem requests: 4Gi

### ✅ Answer 5 — Pod resources + ResourceQuota

Create namespace if needed:

```bash
kubectl create ns dev
```

**Pod:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: heavy-pod
  namespace: dev
spec:
  containers:
    - name: app
      image: nginx
      resources:
        requests:
          cpu: "200m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
```

Apply:

```bash
kubectl apply -f heavy-pod.yaml
```

**ResourceQuota:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: dev
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: "4Gi"
```

Apply:

```bash
kubectl apply -f dev-quota.yaml
```

**Why:** CKAD checks both pod-level `resources` and namespace-level `ResourceQuota` syntax.

---

## 🔥 **QUESTION 6 — Docker Build/Tag/Save (OCI)**

Inside `/root/app`, build image:

- name: `tool:v2`

Save it:

- `/root/tool.tar`

### ✅ Answer 6 — Docker build/tag/save

```bash
cd /root/app
docker build -t tool:v2 .
docker save tool:v2 -o /root/tool.tar
```

**Why:** `docker save` produces a tarball (OCI image layout) – exactly what exams expect.

---

## 🔥 **QUESTION 7 — Canary Deployment**

Stable deployment exists:

```text
name: app-stable
image: app:v1
replicas: 4
```

Create a canary:

```text
name: app-canary
image: app:v2
replicas: 1
```

Both must be reachable through the existing Service with selector `app=app`.

### ✅ Answer 7 — Canary deployment

Stable Pods should have something like:

```yaml
labels:
  app: app
  version: v1
```

Canary:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
      version: v2
  template:
    metadata:
      labels:
        app: app
        version: v2
    spec:
      containers:
        - name: app
          image: app:v2
```

Apply:

```bash
kubectl apply -f app-canary.yaml
```

Service should look like:

```yaml
spec:
  selector:
    app: app
```

**Why:** Both deployments share `app=app` so the Service sees both. Traffic split comes from replica counts.

---

## 🔥 **QUESTION 8 — Fix Service Selector**

A Service:

```yaml
selector:
  tier: web
```

But the Deployment uses:

```yaml
labels:
  app: web
```

Fix ONLY the Service to match the Pod/Deployment.

### ✅ Answer 8 — Fix Service selector

```bash
kubectl edit svc <svc-name> -n <ns>
```

Change selector to:

```yaml
selector:
  app: web
```

**Why:** Services match Pods by labels; this is a classic 2-line fix question.

---

## 🔥 **QUESTION 9 — CronJob Creation**

Create a CronJob:

- name: `backup-cron`
- schedule: `"*/2 * * * *"`
- image: busybox
- command: `echo backing up`

### ✅ Answer 9 — CronJob basic

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-cron
spec:
  schedule: "*/2 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: backup
              image: busybox
              command: ["sh", "-c", "echo backing up"]
```

Apply:

```bash
kubectl apply -f backup-cron.yaml
```

**Why:** `CronJob.spec.jobTemplate.spec.template.spec` is the standard nesting for Pod spec.

---

## 🔥 **QUESTION 10 — CronJob With Completions + BackoffLimit**

Create CronJob `workers-batch`:

- schedule: every minute
- completions: 4
- parallelism: 2
- backoffLimit: 3
- command: `"echo processing"`

(This mirrors your real exam.)

### ✅ Answer 10 — CronJob with completions + backoffLimit

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: workers-batch
spec:
  schedule: "* * * * *"
  jobTemplate:
    spec:
      completions: 4
      parallelism: 2
      backoffLimit: 3
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: worker
              image: busybox
              command: ["sh", "-c", "echo processing"]
```

Apply:

```bash
kubectl apply -f workers-batch.yaml
```

**Why:**

- `completions` & `parallelism` control how many pods per run
- `backoffLimit` = how many failed retries before the job is marked failed.

---

## 🔥 **QUESTION 11 — Deployment SecurityContext**

Edit an existing Deployment `web-deploy`:

- runAsUser: **1000**
- add capability: **NET_ADMIN**

Modify only template spec.

### ✅ Answer 11 — Deployment SecurityContext

```bash
kubectl edit deploy web-deploy -n <ns>
```

Under `spec.template.spec`:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsUser: 1000
      containers:
        - name: <container-name>
          image: ...
          securityContext:
            capabilities:
              add: ["NET_ADMIN"]
```

**Why:**

- Pod-level `runAsUser` sets the default UID.
- Container-level `capabilities` adds `NET_ADMIN` to that container only.

---

## 🔥 **QUESTION 12 — RBAC With ServiceAccount (Hardest in CKAD)**

A Pod `audit-pod` is failing because it is using wrong ServiceAccount.
Logs show it needs access to:

- `get`, `list`, `watch` Pods

Task:

1. Create SA `audit-sa`
2. Create Role `audit-role` with required permissions
3. Bind the Role to SA
4. Patch the pod to use the new SA

### ✅ Answer 12 — RBAC with ServiceAccount

```bash
kubectl create sa audit-sa -n <ns>

kubectl create role audit-role \
  --verb=get --verb=list --verb=watch \
  --resource=pods \
  -n <ns>

kubectl create rolebinding audit-rb \
  --role=audit-role \
  --serviceaccount=<ns>:audit-sa \
  -n <ns>
```

Patch pod:

```bash
kubectl patch pod audit-pod -n <ns> \
  -p '{"spec":{"serviceAccountName":"audit-sa"}}'
```

(or use `kubectl edit` and set `serviceAccountName`.)

**Why:** RBAC = **who** (SA) → **what** (verbs) → **which resource** (Pods).
This is the exact pattern exams test.

---

## 🔥 **QUESTION 13 — Readiness Probe**

Add a readiness probe to Deployment `accounts-api`:

- http
- path `/ready`
- port `8080`
- initialDelaySeconds: 5

### ✅ Answer 13 — Readiness probe on Deployment

```bash
kubectl edit deploy accounts-api -n <ns>
```

Under container spec:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Why:** Readiness = when pod is ready to receive traffic; it always lives under `containers:`.

---

## 🔥 **QUESTION 14 — Liveness Probe**

Add a liveness probe to Pod `livecheck`:

- HTTP
- path `/health`
- port `80`
- initialDelay: `5`

### ✅ Answer 14 — Liveness probe

```bash
kubectl edit pod livecheck -n <ns>
```

Add:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Why:** Liveness decides when Kubernetes should restart a container if it stops responding.

---

## 🔥 **QUESTION 15 — Undo Deployment Rollout**

Deployment `payments` was updated to wrong image.

Undo the last rollout and verify status.

### ✅ Answer 15 — Undo Deployment rollout

```bash
kubectl rollout undo deploy/payments -n <ns>
kubectl rollout status deploy/payments -n <ns>
```

**Why:** `rollout undo` reverts to the previous ReplicaSet. `rollout status` shows completion.

---

## 🔥 **QUESTION 16 — Deprecation Fix**

File `/root/old.yaml` contains:

```yaml
apiVersion: apps/v1beta1
kind: Deployment
strategy:
  rollingUpdate:
    maxSurge: "invalid"
```

Task:

- Update to valid apiVersion for Kubernetes 1.29
- Fix deprecated/invalid fields
- Apply it

### ✅ Answer 16 — Deprecation fix

Edit file:

```bash
vi /root/old.yaml
```

Make it:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: old-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: old
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1 # or "25%"
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: old
    spec:
      containers:
        - name: old
          image: nginx
```

Apply:

```bash
kubectl apply -f /root/old.yaml
```

**Why:**

- `apps/v1beta1` is removed in 1.29; must use `apps/v1`.
- `selector` is mandatory in `apps/v1`.
- `maxSurge` must be an int or valid percentage, not arbitrary string.

---

## 🔥 **QUESTION 17 — Correct VolumeMount Path Issue**

Pod `broken-init` requires an initContainer to create `/app/start.sh`, but script fails because directory does not exist.

Fix by:

- Adding emptyDir volume
- Mount it at `/app` in both initContainer + main container
- InitContainer writes script that echoes `start app`

### ✅ Answer 17 — Fix initContainer + volume mount

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-init
spec:
  volumes:
    - name: app-scripts
      emptyDir: {}
  initContainers:
    - name: init-script
      image: busybox
      command:
        [
          "sh",
          "-c",
          "echo 'echo start app' > /app/start.sh && chmod +x /app/start.sh",
        ]
      volumeMounts:
        - name: app-scripts
          mountPath: /app
  containers:
    - name: app
      image: busybox
      command: ["/app/start.sh"]
      volumeMounts:
        - name: app-scripts
          mountPath: /app
```

Apply:

```bash
kubectl apply -f broken-init.yaml
```

**Why:** `emptyDir` volume is shared; init writes the script to `/app/start.sh`, main container executes it.

---

## 🔥 **QUESTION 18 — Use Correct NetworkPolicy on Pod**

You have a Pod `auth` with wrong labels.

Fix labels so that:

- It is allowed ingress by NP `allow-auth-ingress`
- It is allowed egress by NP `allow-db-egress`

(Don’t modify the policies.)

### ✅ Answer 18 — Use correct NetworkPolicies on Pod

Inspect policies:

```bash
kubectl describe netpol allow-auth-ingress -n <ns>
kubectl describe netpol allow-db-egress -n <ns>
```

Suppose both have:

```yaml
podSelector:
  matchLabels:
    role: auth
    env: prod
```

Label Pod:

```bash
kubectl label pod auth role=auth env=prod -n <ns> --overwrite
```

(Use whatever keys/values appear in both `podSelector` blocks.)

**Why:** Again, NPs are label-based only; you always fix the pod labels to satisfy them.

---

## 🔥 **QUESTION 19 — Fix Misconfigured Ingress PathType**

Ingress definition has:

```yaml
pathType: Exacttt
```

Fix it to valid:

- `Prefix` **or** `Exact` (depending on desired behavior).

### ✅ Answer 19 — Fix Ingress pathType

Valid values are: `Exact`, `Prefix`, `ImplementationSpecific`.

Edit:

```bash
kubectl edit ingress <ing-name> -n <ns>
```

Change to e.g.:

```yaml
pathType: Prefix
```

(or `Exact` if specified in the task.)

**Why:** Invalid enum → Ingress object is rejected or broken.

---

## 🔥 **QUESTION 20 — Pause + Resume Deployment**

Deployment `backend` must be paused, updated, and resumed.

Steps:

1. Pause
2. Set image to `backend:v2`
3. Resume
4. Verify rollout

### ✅ Answer 20 — Pause, update, resume Deployment

```bash
kubectl rollout pause deploy/backend -n <ns>

kubectl set image deploy/backend \
  backend=backend:v2 \
  -n <ns>
# (Use the real container name instead of "backend" if different)

kubectl rollout resume deploy/backend -n <ns>
kubectl rollout status deploy/backend -n <ns>
```

**Why:** This is the typical “controlled rollout” flow they expect you to know.
