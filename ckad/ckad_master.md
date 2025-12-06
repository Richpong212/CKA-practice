````md
# ⭐ THE CKAD MASTER PRACTICE EXAM (20 QUESTIONS + ANSWERS)

Everything here is modeled on actual CKAD exam patterns from 2024–2025 and matches the resources created by `prepare-ckad-practice.sh`.

Namespaces used:

- `prod`
- `dev`
- `netpol-lab`
- `rbac-lab`
- `default`

---

## 🔥 QUESTION 1 — Convert Env Vars to Secret (Classic)

In namespace `prod`, there is a Deployment `db-api` with hardcoded env vars:

```yaml
env:
  - name: USER
    value: "root"
  - name: PASSWORD
    value: "admin123"
```
````

**Tasks:**

1. Create a Secret named `db-credentials` in namespace `prod` with these two keys.
2. Update Deployment `db-api` so that these env vars are loaded from the Secret (use individual `valueFrom`, not `envFrom`).

---

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

Change the `env` section on the container to:

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

**Why:** CKAD loves this pattern: move hard-coded creds into a Secret and use `valueFrom.secretKeyRef`.

---

## 🔥 QUESTION 2 — Ingress Fix (Wrong Service Name / Port)

In namespace `default`:

- Service `web-svc` exists and exposes port `8080`.
- Deployment `web-deploy-main` backs it.
- Ingress `web-bad-ingress` exists but does **not** route correctly.

You discover that `web-bad-ingress` has:

- Wrong Service name
- Wrong Service port

**Task:** Fix `web-bad-ingress` so it sends traffic to Service `web-svc` on port `8080`.

---

### ✅ Answer 2 — Ingress: wrong Service name/port

Edit the Ingress:

```bash
kubectl edit ingress web-bad-ingress -n default
```

Fix its backend to:

```yaml
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-svc # correct service name
                port:
                  number: 8080 # correct service port
```

**Why:** In `networking.k8s.io/v1`, the backend is nested under `service.name` and `service.port.number`. If either is wrong, routing fails.

---

## 🔥 QUESTION 3 — Ingress With Hostname

In namespace `default`, there is:

- Service `api-svc` exposing port `3000`.
- Deployment `api-deployment` backing `api-svc`.

**Task:** Create an Ingress named `api-ing` in namespace `default` that:

- Routes host `api.example.com`
- Path `/`
- To Service `api-svc` on port `3000`.

---

### ✅ Answer 3 — Ingress with hostname

Create `api-ing.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ing
  namespace: default
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

Apply it:

```bash
kubectl apply -f api-ing.yaml
```

**Why:** This is the standard Ingress structure in Kubernetes 1.19+ and what CKAD expects you to know.

---

## 🔥 QUESTION 4 — NetworkPolicy Label Assignment

In namespace `netpol-lab` you have 3 Pods:

- `frontend`
- `backend`
- `database`

Their labels are currently **wrong** (e.g. `role: frontend-initial`, etc.).

There are 4 existing NetworkPolicies:

- `allow-frontend-to-backend`
- `allow-backend-to-db`
- `deny-all`
- `allow-frontend-http`

**Goal:** Make traffic flow from:

`frontend` → `backend` → `database`

by **only changing Pod labels**, not the NetworkPolicies.

---

### ✅ Answer 4 — NetworkPolicy: use correct labels on Pods

Inspect the NetworkPolicies:

```bash
kubectl get netpol -n netpol-lab
kubectl describe netpol allow-frontend-to-backend -n netpol-lab
kubectl describe netpol allow-backend-to-db -n netpol-lab
kubectl describe netpol allow-frontend-http -n netpol-lab
```

You’ll see selectors like:

```yaml
# allow-frontend-to-backend
podSelector:
  matchLabels:
    role: backend
---
from:
  - podSelector:
      matchLabels:
        role: frontend

# allow-backend-to-db
podSelector:
  matchLabels:
    role: db
---
from:
  - podSelector:
      matchLabels:
        role: backend
```

Update Pod labels to match:

```bash
kubectl label pod frontend role=frontend -n netpol-lab --overwrite
kubectl label pod backend role=backend -n netpol-lab --overwrite
kubectl label pod database role=db -n netpol-lab --overwrite
```

**Why:** NetworkPolicies match **only** by `podSelector.matchLabels`. To “use the correct policies”, you almost always change Pod labels, not the policies.

---

## 🔥 QUESTION 5 — Resource Limits + Quota

In namespace `dev`:

1. Create a Pod `heavy-pod` with:

   - CPU requests: `200m`
   - CPU limits: `500m`
   - Memory requests: `128Mi`
   - Memory limits: `256Mi`
   - Image: `nginx`

2. Create a ResourceQuota `dev-quota` in namespace `dev` with:

   - `pods: 10`
   - `requests.cpu: 2`
   - `requests.memory: 4Gi`

---

### ✅ Answer 5 — Pod resources + ResourceQuota

Make sure namespace exists (script already does this, but safe):

```bash
kubectl create ns dev --dry-run=client -o yaml | kubectl apply -f -
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

**Why:** CKAD checks correct `resources` syntax on Pods and `ResourceQuota` syntax on namespaces.

---

## 🔥 QUESTION 6 — Docker Build/Tag/Save (OCI)

On the node filesystem, the script created `/root/app` with a `Dockerfile`.

**Task:**

- Build an image named `tool:v2` using `/root/app`.
- Save it as `/root/tool.tar`.

---

### ✅ Answer 6 — Docker build/tag/save

```bash
cd /root/app
docker build -t tool:v2 .
docker save tool:v2 -o /root/tool.tar
```

**Why:** `docker save` creates an OCI-compatible tarball, which is exactly what “save to OCI format” means in these exams.

---

## 🔥 QUESTION 7 — Canary Deployment

In namespace `default`, you already have:

- Deployment `app-stable`

  - `image: nginx` (representing `app:v1`)
  - `replicas: 4`
  - labels: `app: app`, `version: v1`

- Service `app-service` with selector `app: app`.

**Task:** Create a canary deployment:

- name: `app-canary`
- image: `nginx` (representing `app:v2`)
- replicas: `1`
- labels: `app: app`, `version: v2`

So that both `app-stable` and `app-canary` are behind `app-service`.

---

### ✅ Answer 7 — Canary deployment

`app-stable` is already labeled correctly by the script. Create canary:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
  namespace: default
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
          image: nginx
          ports:
            - containerPort: 80
```

Apply:

```bash
kubectl apply -f app-canary.yaml
```

Service `app-service`:

```yaml
spec:
  selector:
    app: app
```

will now send traffic to both v1 and v2 Pods.

**Why:** Canary is just “small replicas + same Service selector”. Traffic split is based on replica counts when labels match.

---

## 🔥 QUESTION 8 — Fix Service Selector

In namespace `default`:

- Deployment `web-app` has Pods with label: `app: web`.
- Service `web-app-svc` has a wrong selector:

```yaml
selector:
  tier: web
```

**Task:** Fix Service `web-app-svc` so it correctly selects Pods from `web-app`.

---

### ✅ Answer 8 — Fix Service selector

Edit the Service:

```bash
kubectl edit svc web-app-svc -n default
```

Change:

```yaml
selector:
  tier: web
```

to:

```yaml
selector:
  app: web
```

**Why:** Services route based on Pod labels; if the selector doesn’t match, endpoints list is empty and the Service doesn’t work.

---

## 🔥 QUESTION 9 — CronJob Creation

**Task:** In namespace `default`, create a CronJob:

- name: `backup-cron`
- schedule: `"*/2 * * * *"` (every 2 minutes)
- image: `busybox`
- command: `echo backing up`

---

### ✅ Answer 9 — CronJob basic

Create `backup-cron.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-cron
  namespace: default
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

**Why:** CronJob → `jobTemplate.spec.template.spec` → Pod spec. This nesting always shows up.

---

## 🔥 QUESTION 10 — CronJob With Completions + BackoffLimit

**Task:** In namespace `default`, create a CronJob `workers-batch`:

- schedule: `* * * * *` (every minute)
- completions: `4`
- parallelism: `2`
- backoffLimit: `3`
- image: `busybox`
- command: `echo processing`

---

### ✅ Answer 10 — CronJob with completions + backoffLimit

`workers-batch.yaml`:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: workers-batch
  namespace: default
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

- `completions`: how many pods must succeed per job.
- `parallelism`: how many pods run at the same time.
- `backoffLimit`: how many failed retries per job before considering it failed.

---

## 🔥 QUESTION 11 — Deployment SecurityContext

In namespace `default`, Deployment `web-deploy` exists with a container `web` and **no** security context.

**Task:** Edit `web-deploy` so that:

- Pod-level `runAsUser` is `1000`.
- Container `web` has capability `NET_ADMIN` added.

---

### ✅ Answer 11 — Deployment SecurityContext

Edit:

```bash
kubectl edit deploy web-deploy -n default
```

Under `spec.template.spec`:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsUser: 1000
      containers:
        - name: web
          image: nginx
          securityContext:
            capabilities:
              add: ["NET_ADMIN"]
```

**Why:** Pod-level `runAsUser` sets default UID for containers; container-level `capabilities.add` adds `NET_ADMIN` just for that container.

---

## 🔥 QUESTION 12 — RBAC With ServiceAccount (Hard)

In namespace `rbac-lab`:

- ServiceAccount `wrong-sa` exists.
- Pod `audit-pod` uses `wrong-sa` and tries to run:

  ```sh
  kubectl get pods --all-namespaces
  ```

  It fails due to permissions.

**Task:**

1. Create ServiceAccount `audit-sa` in `rbac-lab`.
2. Create Role `audit-role` in `rbac-lab` that allows `get`, `list`, `watch` on `pods`.
3. Create RoleBinding `audit-rb` binding `audit-role` to `audit-sa`.
4. Update `audit-pod` to use `audit-sa`.

---

### ✅ Answer 12 — RBAC with ServiceAccount

Create SA:

```bash
kubectl create sa audit-sa -n rbac-lab
```

Create Role:

```bash
kubectl create role audit-role \
  --verb=get --verb=list --verb=watch \
  --resource=pods \
  -n rbac-lab
```

Create RoleBinding:

```bash
kubectl create rolebinding audit-rb \
  --role=audit-role \
  --serviceaccount=rbac-lab:audit-sa \
  -n rbac-lab
```

Patch Pod to use `audit-sa`:

```bash
kubectl patch pod audit-pod -n rbac-lab \
  -p '{"spec":{"serviceAccountName":"audit-sa"}}'
```

(Alternatively, delete and recreate the Pod with the new SA.)

**Why:** RBAC is “who (ServiceAccount) → what (verbs) → which resource (pods) → in which namespace”.

---

## 🔥 QUESTION 13 — Readiness Probe

In namespace `default`, Deployment `accounts-api` exists with container `accounts` on port `8080`.

**Task:** Add a readiness probe:

- HTTP GET on `/ready`
- Port `8080`
- `initialDelaySeconds: 5`

---

### ✅ Answer 13 — Readiness probe on Deployment

Edit the Deployment:

```bash
kubectl edit deploy accounts-api -n default
```

Under the `accounts` container:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Why:** Readiness probes determine when the pod is ready to receive traffic from a Service. Always under `containers:`.

---

## 🔥 QUESTION 14 — Liveness Probe

In namespace `default`, Pod `livecheck` exists with a single `nginx` container exposing port `80`.

**Task:** Add a liveness probe:

- HTTP GET on `/health`
- Port `80`
- `initialDelaySeconds: 5`

---

### ✅ Answer 14 — Liveness probe

Edit the Pod:

```bash
kubectl edit pod livecheck -n default
```

Add under the container:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Why:** Liveness probes tell Kube when to restart a container that is stuck/unhealthy.

---

## 🔥 QUESTION 15 — Undo Deployment Rollout

In namespace `default`, the script:

- Created `payments` Deployment with `image: nginx:1.25`.
- Then updated it to `image: nginx:bad-tag` to create a bad revision.

**Task:**

1. Undo the last rollout for Deployment `payments`.
2. Verify that the rollout is successful.

---

### ✅ Answer 15 — Undo Deployment rollout

```bash
kubectl rollout undo deploy/payments -n default
kubectl rollout status deploy/payments -n default
```

**Why:** `rollout undo` reverts to the previous ReplicaSet revision. `rollout status` ensures the rollback finished successfully.

---

## 🔥 QUESTION 16 — Deprecation Fix

The script created `/root/old.yaml` with:

```yaml
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
```

**Task:**

- Update this file to a **valid** `Deployment` manifest for Kubernetes `1.29`.
- Use `apps/v1`.
- Fix the invalid `strategy` fields.
- Apply it.

---

### ✅ Answer 16 — Deprecation fix

Edit the file:

```bash
vi /root/old.yaml
```

Make it something like:

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
      maxSurge: 1
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

- `apps/v1beta1` is removed in modern clusters; must use `apps/v1`.
- `spec.selector` is mandatory and must match Pod labels.
- `maxSurge` cannot be `"invalid"`; must be an integer or valid percentage string.

---

## 🔥 QUESTION 17 — Correct VolumeMount Path Issue

In namespace `default`, the script created a Pod `broken-init`:

```yaml
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
```

The pod fails because `/app/start.sh` doesn’t exist.

**Task:** Fix this by:

- Using an `emptyDir` volume.
- Mounting it at `/app` for both an initContainer and the main container.
- Having the initContainer create `/app/start.sh` with content `echo start app` and make it executable.

---

### ✅ Answer 17 — Fix initContainer + volume mount

Because Pod spec changes are not fully patchable, easiest is to delete & recreate:

```bash
kubectl delete pod broken-init -n default --ignore-not-found
```

Create `broken-init-fixed.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: broken-init
  namespace: default
spec:
  volumes:
    - name: app-scripts
      emptyDir: {}
  initContainers:
    - name: init-script
      image: busybox
      command:
        - sh
        - -c
        - "echo 'echo start app' > /app/start.sh && chmod +x /app/start.sh"
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
kubectl apply -f broken-init-fixed.yaml
```

**Why:** `emptyDir` volumes are shared between init containers and main containers. Init writes the script, main executes it.

---

## 🔥 QUESTION 18 — Use Correct NetworkPolicy on Pod

In namespace `netpol-lab`:

- Pod `auth` has wrong labels: `role: wrong-auth`, `env: dev`.
- Pod `db` has labels: `role: db`, `env: prod`.
- There are two NetworkPolicies:

  - `allow-auth-ingress`
  - `allow-db-egress`

They both expect `auth` Pods to have labels:

```yaml
role: auth
env: prod
```

**Task:** Update `auth` Pod labels so that it:

- Matches `allow-auth-ingress` `podSelector`
- Matches `allow-db-egress` `podSelector`

Do **not** modify the policies.

---

### ✅ Answer 18 — Use correct NetworkPolicies on Pod

Inspect policies:

```bash
kubectl describe netpol allow-auth-ingress -n netpol-lab
kubectl describe netpol allow-db-egress -n netpol-lab
```

You’ll see:

```yaml
podSelector:
  matchLabels:
    role: auth
    env: prod
```

Relabel `auth`:

```bash
kubectl label pod auth role=auth env=prod -n netpol-lab --overwrite
```

**Why:** NetworkPolicies match by Pod labels; making `auth` match the `podSelector` means these policies now apply to it.

---

## 🔥 QUESTION 19 — Fix Misconfigured Ingress PathType

In namespace `default`, the script created:

- Service `path-test-svc`
- Deployment `path-test-deploy`
- Ingress `bad-path-ingress` with:

```yaml
pathType: Exacttt
```

**Task:** Fix `bad-path-ingress` to use a valid `pathType`, such as `Prefix`.

---

### ✅ Answer 19 — Fix Ingress pathType

Edit the Ingress:

```bash
kubectl edit ingress bad-path-ingress -n default
```

Change:

```yaml
pathType: Exacttt
```

to:

```yaml
pathType: Prefix
```

(or `Exact` if the question specifies exact matching.)

**Why:** Valid `pathType` values are `Exact`, `Prefix`, `ImplementationSpecific`. Any other string breaks the Ingress object.

---

## 🔥 QUESTION 20 — Pause + Resume Deployment

In namespace `default`, Deployment `backend` exists with container `backend` and image `nginx:1.25`.

**Task:**

1. Pause the rollout of Deployment `backend`.
2. Update its image to `backend:v2` (use `nginx:1.27` to simulate in this lab, for example).
3. Resume the rollout.
4. Verify the rollout status.

---

### ✅ Answer 20 — Pause, update, resume Deployment

Pause:

```bash
kubectl rollout pause deploy/backend -n default
```

Update image (use a real tag; we’ll say `nginx:1.27`):

```bash
kubectl set image deploy/backend \
  backend=nginx:1.27 \
  -n default
```

Resume:

```bash
kubectl rollout resume deploy/backend -n default
```

Verify:

```bash
kubectl rollout status deploy/backend -n default
```

**Why:** This is the standard controlled rollout flow: pause → change → resume → watch status.

---

```

You can now:

- Run the shell script in KillerKoda to prep the environment.
- Use this markdown as your **exam-style workbook**.
- Practice each question using the exact resource names and namespaces that already exist in the cluster.
::contentReference[oaicite:0]{index=0}
```
