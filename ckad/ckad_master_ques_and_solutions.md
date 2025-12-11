# CKAD Practice Exam – 25 Tasks (2025-Style)

The cluster is preconfigured using `prep.sh`.
Use the existing resources where applicable.
Unless otherwise specified, use namespace `default`.

---

## Question 1 – Move hardcoded env vars to Secret

In namespace `default`, Deployment `billing-api` exists with hard-coded environment variables:

- `DB_USER`
- `DB_PASS`

Update the configuration to:

1. Create a Secret named `billing-secret` in namespace `default` containing keys:

   - `DB_USER`
   - `DB_PASS`

2. Modify Deployment `billing-api` so that the container reads `DB_USER` and `DB_PASS` from this Secret using `valueFrom.secretKeyRef`.

Do not change the Deployment name or namespace.

### Solution

**Step 1 – Create the Secret**

```bash
kubectl create secret generic billing-secret \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASS=SuperSecret123
```

**Step 2 – Patch Deployment env to use Secret**

```bash
kubectl edit deploy billing-api
```

Inside `.spec.template.spec.containers[0].env`, replace:

```yaml
- name: DB_USER
  value: "admin"
- name: DB_PASS
  value: "SuperSecret123"
```

with:

```yaml
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: billing-secret
      key: DB_USER
- name: DB_PASS
  valueFrom:
    secretKeyRef:
      name: billing-secret
      key: DB_PASS
```

Save and exit. The Deployment will roll out new Pods.

**Why this works**

- You externalize sensitive data into a Secret and mount it via `env.valueFrom.secretKeyRef`.
- This matches the real exam theme: “convert env vars to Secret-based configuration.”

**Docs**

- Secrets & env: [https://kubernetes.io/docs/concepts/configuration/secret/](https://kubernetes.io/docs/concepts/configuration/secret/)

---

## Question 2 – Fix broken Ingress backend and pathType

In namespace `default`, the following resources exist:

- Deployment `store-deploy`
- Service `store-svc`
- Ingress `store-ingress` (currently misconfigured)

The Ingress must:

- Route HTTP requests to path `/shop`
- Use `pathType: Prefix`
- Forward traffic to Service `store-svc` on port `8080`

Reconfigure Ingress `store-ingress` accordingly.
Do not create a new Ingress.

### Solution

Edit the Ingress:

```bash
kubectl edit ingress store-ingress
```

Update the rule under `.spec.rules[0].http.paths[0]` to:

```yaml
path: /shop
pathType: Prefix
backend:
  service:
    name: store-svc
    port:
      number: 8080
```

Save and exit.

**Why this works**

- `Prefix` is a valid `pathType` and commonly used.
- Backend service name and port now match `store-svc:8080`, so traffic from the Ingress actually reaches the Pods behind `store-deploy`.

**Docs**

- Ingress basics: [https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

## Question 3 – Create Ingress for internal API

In namespace `default`, the following resources exist:

- Deployment `internal-api`
- Service `internal-api-svc` exposing port `3000`

Create an Ingress named `internal-api-ingress` in namespace `default` that:

- Routes host `internal.company.local`
- Path `/`
- To Service `internal-api-svc` on port `3000`
- Uses the stable `networking.k8s.io/v1` API

### Solution

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: internal-api-ingress
  namespace: default
spec:
  rules:
    - host: internal.company.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: internal-api-svc
                port:
                  number: 3000
EOF
```

**Why this works**

- Uses the stable `networking.k8s.io/v1` API with `spec.rules[].http.paths[].pathType`.
- The rule matches host + path and routes to the correct service and port.

**Docs**

- Ingress V1 API: [https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

## Question 4 – Fix RBAC for a Deployment using logs hint

In namespace `meta`, Deployment `dev-deployment` exists.
Its Pods run a `kubectl` loop trying to list Deployments in the same namespace and log an authorization error.

Without deleting the Deployment, perform the following:

1. Create a ServiceAccount `dev-sa` in namespace `meta`.
2. Create a Role `dev-deploy-role` in namespace `meta` that allows `get`, `list`, and `watch` on resource `deployments` in API group `apps`.
3. Create a RoleBinding `dev-deploy-rb` in namespace `meta` binding `dev-deploy-role` to `dev-sa`.
4. Update Deployment `dev-deployment` so that its Pods run using ServiceAccount `dev-sa`.

### Solution

**Step 1 – SA**

```bash
kubectl create sa dev-sa -n meta
```

**Step 2 – Role**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: dev-deploy-role
  namespace: meta
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]
EOF
```

**Step 3 – RoleBinding**

```bash
kubectl create rolebinding dev-deploy-rb \
  --role=dev-deploy-role \
  --serviceaccount=meta:dev-sa \
  -n meta
```

**Step 4 – Patch Deployment**

```bash
kubectl patch deploy dev-deployment -n meta \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"dev-sa"}}}}'
```

**Why this works**

- The Pod was using the default SA with no RBAC.
- Granting a Role over `deployments` and binding it to a dedicated SA, then setting that SA on the Deployment, resolves the authorization error.

**Docs**

- RBAC: [https://kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## Question 5 – Fix pod using initContainer + emptyDir

In namespace `default`, Pod `startup-pod` exists and fails because it tries to execute `/app/start.sh`, which does not exist.

Recreate Pod `startup-pod` so that:

- It uses an `emptyDir` volume mounted at `/app`.
- An init container:

  - Writes `/app/start.sh` with content `echo start app`
  - Marks it executable

- The main container:

  - Runs `/app/start.sh` as its command

Ensure the recreated Pod reaches `Running` state.

### Solution

Delete and recreate:

```bash
kubectl delete pod startup-pod
```

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: startup-pod
  namespace: default
spec:
  volumes:
    - name: app-vol
      emptyDir: {}
  initContainers:
    - name: init-script
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - |
          echo 'echo start app' > /app/start.sh
          chmod +x /app/start.sh
      volumeMounts:
        - name: app-vol
          mountPath: /app
  containers:
    - name: app
      image: busybox
      command: ["/app/start.sh"]
      volumeMounts:
        - name: app-vol
          mountPath: /app
EOF
```

**Why this works**

- `emptyDir` shares the filesystem between init and main container.
- Init container prepares the script and makes it executable before the main container starts.

**Docs**

- Init containers: [https://kubernetes.io/docs/concepts/workloads/pods/init-containers/](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- Volumes: [https://kubernetes.io/docs/concepts/storage/volumes/](https://kubernetes.io/docs/concepts/storage/volumes/)

---

## Question 6 – Build, tag, and save Docker image

On the node filesystem, directory `/root/api-app` contains a valid `Dockerfile`.

Using available container tools:

1. Build an image named `api-app:2.1` using `/root/api-app` as build context.
2. Save this image into `/root/api-app.tar` as a container image archive.

Do not modify the directory layout.

### Solution

From the node:

```bash
cd /root/api-app

docker build -t api-app:2.1 .
docker save api-app:2.1 -o /root/api-app.tar
```

(If using `ctr` / `nerdctl`, adapt accordingly, but the idea is the same.)

**Why this works**

- `docker build` uses the Dockerfile in the directory.
- `docker save` creates a tarball you can upload, import, or scan.

**Docs**

- Docker build/save: [https://docs.docker.com/reference/cli/docker/image/build/](https://docs.docker.com/reference/cli/docker/image/build/)
- Container runtimes in K8s: [https://kubernetes.io/docs/setup/production-environment/container-runtimes/](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

---

## Question 7 – Pod resources + namespace ResourceQuota

In namespace `dev`, perform the following:

1. Create a Pod named `resource-pod` with:

   - Image: `nginx`
   - CPU request: `200m`
   - CPU limit: `500m`
   - Memory request: `128Mi`
   - Memory limit: `256Mi`

2. Create a ResourceQuota named `dev-quota` that enforces:

   - Maximum number of Pods: `10`
   - Total CPU requests: `2`
   - Total memory requests: `4Gi`

Ensure both resources are created in namespace `dev`.

### Solution

**Pod**

```bash
kubectl apply -n dev -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: resource-pod
spec:
  containers:
    - name: web
      image: nginx
      resources:
        requests:
          cpu: "200m"
          memory: "128Mi"
        limits:
          cpu: "500m"
          memory: "256Mi"
EOF
```

**ResourceQuota**

```bash
kubectl apply -n dev -f - <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
spec:
  hard:
    pods: "10"
    requests.cpu: "2"
    requests.memory: "4Gi"
EOF
```

**Why this works**

- Requests/limits are set at the container level.
- ResourceQuota enforces aggregate usage in the namespace.

**Docs**

- Resource requests/limits: [https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- ResourceQuota: [https://kubernetes.io/docs/concepts/policy/resource-quotas/](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

---

## Question 8 – Fix deprecated manifest and strategy

File `/root/old.yaml` contains a Deployment manifest using a deprecated API version and invalid rolling update configuration.

Update `/root/old.yaml` so that:

- It uses `apiVersion: apps/v1`.
- It specifies a valid `.spec.selector` that matches Pod template labels `app: old-app`.
- It has a valid rolling update strategy under `.spec.strategy.rollingUpdate` with sane values.

Apply the updated manifest so that Deployment `old-deploy` is created successfully.

### Solution

Edit the file:

```bash
vi /root/old.yaml
```

Turn it into something like:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: old-deploy
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: old-app
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
  template:
    metadata:
      labels:
        app: old-app
    spec:
      containers:
        - name: old-container
          image: nginx:1.14
```

Apply:

```bash
kubectl apply -f /root/old.yaml
```

**Why this works**

- `apps/v1` requires `.spec.selector` and matching template labels.
- `maxSurge` and `maxUnavailable` must be valid ints or percentages.

**Docs**

- Deployments: [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

## Question 9 – Create a canary Deployment behind existing Service

In namespace `default`, the following resources exist:

- Deployment `app-stable` with labels `app=core`, `version=v1`
- Service `app-svc` with selector `app=core`

Create an additional Deployment named `app-canary` with:

- Labels: `app=core`, `version=v2`
- Image: `nginx`
- Replicas: `1`

Ensure both `app-stable` and `app-canary` Pods are selected by `app-svc`.

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-canary
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: core
      version: v2
  template:
    metadata:
      labels:
        app: core
        version: v2
    spec:
      containers:
        - name: app
          image: nginx
EOF
```

**Why this works**

- Both Deployments share `app=core`.
- Service `app-svc` selects `app=core`, so traffic is split between v1 and v2 Pods = canary pattern.

**Docs**

- Canary pattern (general): [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment)

---

## Question 10 – Fix Service selector for Deployment

In namespace `default`, the following resources exist:

- Deployment `web-app` with Pods labeled `app=webapp`
- Service `web-app-svc` with an incorrect selector

Update Service `web-app-svc` so it correctly selects Pods created by Deployment `web-app`.

Do not rename resources.

### Solution

```bash
kubectl edit svc web-app-svc
```

Change:

```yaml
spec:
  selector:
    app: wronglabel
```

to:

```yaml
spec:
  selector:
    app: webapp
```

Save and exit.

**Why this works**

- Service selectors must match Pod labels to direct traffic.
- Once fixed, endpoints will be populated with the `web-app` Pods.

**Docs**

- Services: [https://kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/)

---

## Question 11 – Add livenessProbe to Pod

In namespace `default`, Pod `healthz` exists with a single container:

- Image: `nginx`
- Container port: `80`

Modify configuration so that Pod `healthz` has a liveness probe:

- HTTP GET path `/healthz`
- Port `80`
- `initialDelaySeconds: 5`

If direct editing is not possible, delete and recreate `healthz` with the required liveness probe.

### Solution

Simplest: delete and recreate:

```bash
kubectl delete pod healthz
```

```bash
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
      livenessProbe:
        httpGet:
          path: /healthz
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 10
EOF
```

**Why this works**

- Liveness probe checks container health and restarts it when failing.
- You’re matching the required path, port, and initial delay.

**Docs**

- Probes: [https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

---

## Question 12 – Add readinessProbe to Deployment

In namespace `default`, Deployment `shop-api` exists with a container listening on port `8080`.

Update Deployment `shop-api` to add a readiness probe with:

- HTTP GET path `/ready`
- Port `8080`
- `initialDelaySeconds: 5`

Ensure the Deployment rolls out successfully.

### Solution

```bash
kubectl edit deploy shop-api
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

Save; check rollout:

```bash
kubectl rollout status deploy shop-api
```

**Why this works**

- Readiness probe gates sending traffic to the Pod until it’s ready.
- This is heavily used in CKAD for application readiness.

**Docs**

- Readiness probes: [https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)

---

## Question 13 – Create CronJob with completions/parallelism/backoff

In namespace `default`, create a CronJob named `metrics-job` with:

- Schedule: every minute (`* * * * *`)
- Image: `busybox`
- Container prints `collecting metrics` to stdout
- Job template configuration:

  - `completions: 4`
  - `parallelism: 2`
  - `backoffLimit: 3`

- Pods must not restart after completion (`restartPolicy: Never`)

Use the stable CronJob API.

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: metrics-job
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
            - name: metrics
              image: busybox
              command: ["/bin/sh","-c"]
              args: ["echo collecting metrics; sleep 5"]
EOF
```

**Why this works**

- `jobTemplate.spec` holds Job fields like `completions`, `parallelism`, `backoffLimit`.
- Pod template uses `restartPolicy: Never`, as required.

**Docs**

- CronJobs: [https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

---

## Question 14 – Fix RBAC for audit Pod in default namespace

In namespace `default`:

- ServiceAccount `wrong-sa` exists.
- Pod `audit-runner` uses ServiceAccount `wrong-sa` and runs `kubectl get pods --all-namespaces` in a loop but lacks permissions.

Perform:

1. Create a ServiceAccount `audit-sa` in namespace `default`.
2. Create a Role `audit-role` in namespace `default` that grants `get`, `list`, `watch` on resource `pods`.
3. Create a RoleBinding `audit-rb` in namespace `default` binding `audit-role` to `audit-sa`.
4. Reconfigure Pod `audit-runner` to use `audit-sa`.

### Solution

**SA**

```bash
kubectl create sa audit-sa
```

**Role**

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: audit-role
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
EOF
```

**RoleBinding**

```bash
kubectl create rolebinding audit-rb \
  --role=audit-role \
  --serviceaccount=default:audit-sa \
  -n default
```

**Recreate Pod with SA**

Easiest: delete and recreate using `kubectl edit` or manual manifest. For speed, patch:

```bash
kubectl patch pod audit-runner \
  -p '{"spec":{"serviceAccountName":"audit-sa"}}'
```

(If patch fails because of immutable fields, delete and re-apply Pod.)

**Why this works**

- RBAC is namespace-scoped for Role/RoleBinding.
- SA must match the subject in RoleBinding and be set on the Pod.

**Docs**

- RBAC: [https://kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## Question 15 – Capture Pod logs to file on node

In namespace `default`, Pod `winter` exists.

On the node, capture its current logs and write them to file:

- `/opt/winter/logs.txt`

You may run commands from the control plane node using `kubectl`.

### Solution

On the node:

```bash
mkdir -p /opt/winter
kubectl logs winter > /opt/winter/logs.txt
```

**Why this works**

- `kubectl logs` outputs container logs.
- Redirecting to a file on the node satisfies the requirement.

**Docs**

- Viewing logs: [https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)

---

## Question 16 – Find highest CPU Pod and write name to file

In namespace `cpu-load`, Pods `cpu-busy-1` and `cpu-busy-2` run a CPU-intensive workload.

Using `kubectl top`, determine which Pod currently uses the most CPU and write its **name only** (no extra spaces/newlines) into the file:

- `/opt/winter/highest.txt`

### Solution

First, get metrics:

```bash
kubectl top pod -n cpu-load
```

Suppose output shows `cpu-busy-2` has higher CPU.

Then:

```bash
echo -n "cpu-busy-2" > /opt/winter/highest.txt
```

(Use whichever Pod name actually has the highest CPU when you run `kubectl top`.)

**Why this works**

- `kubectl top` uses metrics-server and shows live resource usage.
- The task checks that the name in the file matches a real Pod in `cpu-load`.

**Docs**

- Metrics / `kubectl top`: [https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/)

---

## Question 17 – Expose Deployment via NodePort Service

In namespace `default`, Deployment `video-api` exists with Pods labeled `app=video-api` and container port `9090`.

Create a Service `video-svc` that:

- Type: `NodePort`
- Selects `app=video-api`
- Exposes Service port `80` mapping to target port `9090`

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: video-svc
  namespace: default
spec:
  type: NodePort
  selector:
    app: video-api
  ports:
    - port: 80
      targetPort: 9090
EOF
```

**Why this works**

- `NodePort` exposes the Service externally on all nodes.
- Port translation 80 → 9090 matches the requirement.

**Docs**

- Service types: [https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types](https://kubernetes.io/docs/concepts/services-networking/service/#publishing-services-service-types)

---

## Question 18 – Fix Ingress pathType from invalid manifest

On the node, file `/root/client-ingress.yaml` contains an Ingress manifest that fails to apply because it uses an invalid `pathType` value.

Your task:

1. Apply `/root/client-ingress.yaml` and observe the error.
2. Fix the `pathType` in the manifest to use a valid value.
3. Ensure the Ingress `client-ingress` is created in namespace `default`, routing:

   - Path `/`
   - To Service `client-svc`
   - On port `80`

### Solution

**Step 1 – Try applying**

```bash
kubectl apply -f /root/client-ingress.yaml
# Observe error about Unsupported value "InvalidType"
```

**Step 2 – Edit manifest**

```bash
vi /root/client-ingress.yaml
```

Change:

```yaml
pathType: InvalidType
```

to:

```yaml
pathType: Prefix
```

(or `Exact` / `ImplementationSpecific`, but we’ll use `Prefix`.)

Ensure backend:

```yaml
backend:
  service:
    name: client-svc
    port:
      number: 80
```

**Step 3 – Apply again**

```bash
kubectl apply -f /root/client-ingress.yaml
```

**Why this works**

- Ingress v1 supports only `Exact`, `Prefix`, `ImplementationSpecific`.
- Once valid, the resource is accepted and routes traffic.

**Docs**

- Ingress pathType: [https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types](https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types)

---

## Question 19 – Add Pod-level securityContext and capability

In namespace `default`, Deployment `syncer` exists with:

- No `securityContext` set.

Update Deployment `syncer` so that:

- At Pod level, `runAsUser: 1000`.
- At container level (`sync` container), add capability `NET_ADMIN`.

### Solution

```bash
kubectl edit deploy syncer
```

Add under `spec.template.spec`:

```yaml
securityContext:
  runAsUser: 1000
```

And under the container:

```yaml
securityContext:
  capabilities:
    add:
      - NET_ADMIN
```

Full container snippet:

```yaml
containers:
  - name: sync
    image: nginx
    securityContext:
      capabilities:
        add:
          - NET_ADMIN
```

Save, then verify rollout:

```bash
kubectl rollout status deploy syncer
```

**Why this works**

- Pod-level `runAsUser` enforces UID.
- Container `capabilities.add` augments Linux capabilities, including `NET_ADMIN`.

**Docs**

- Pod securityContext: [https://kubernetes.io/docs/tasks/configure-pod-container/security-context/](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)

---

## Question 20 – Create Redis Pod in specific namespace

In namespace `cachelayer`, create a Pod named `redis32` that:

- Uses image `redis:3.2`
- Exposes container port `6379`

### Solution

```bash
kubectl apply -n cachelayer -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: redis32
spec:
  containers:
    - name: redis
      image: redis:3.2
      ports:
        - containerPort: 6379
EOF
```

**Why this works**

- Matches name, image, and port exactly.
- Namespace `cachelayer` was created by `prep.sh`.

**Docs**

- Pods basics: [https://kubernetes.io/docs/concepts/workloads/pods/](https://kubernetes.io/docs/concepts/workloads/pods/)

---

## Question 21 – Fix labels to match existing NetworkPolicies

In namespace `netpol-chain`:

- Pods `frontend`, `backend`, and `database` exist with incorrect labels:

  - `role=wrong-frontend`, `role=wrong-backend`, `role=wrong-db`

- NetworkPolicies exist:

  - `deny-all`
  - `allow-frontend-to-backend` (selects `role=backend` and allows from `role=frontend`)
  - `allow-backend-to-db` (selects `role=db` and allows from `role=backend`)

Without modifying any NetworkPolicy objects, update the labels on Pods `frontend`, `backend`, and `database` so that traffic is allowed in the chain:

`frontend` → `backend` → `database`.

### Solution

Patch labels:

```bash
kubectl label pod frontend -n netpol-chain role=frontend --overwrite
kubectl label pod backend  -n netpol-chain role=backend  --overwrite
kubectl label pod database -n netpol-chain role=db       --overwrite
```

**Why this works**

- NetworkPolicies already reference `role=frontend`, `role=backend`, `role=db`.
- Aligning Pod labels with selectors activates the desired flows.

**Docs**

- NetworkPolicy: [https://kubernetes.io/docs/concepts/services-networking/network-policies/](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

## Question 22 – Resume paused rollout and update image

In namespace `default`, Deployment `dashboard` exists and its rollout has been paused. It currently uses image `nginx:1.23`.

Perform:

1. Resume the rollout.
2. Update the container image to `nginx:1.25`.
3. Verify the rollout completes successfully and the new image is in use.

### Solution

**Step 1 – Resume**

```bash
kubectl rollout resume deploy dashboard
```

**Step 2 – Update image**

```bash
kubectl set image deploy/dashboard web=nginx:1.25
```

**Step 3 – Verify**

```bash
kubectl rollout status deploy dashboard
kubectl get deploy dashboard -o jsonpath='{.spec.template.spec.containers[0].image}'
# should output: nginx:1.25
```

**Why this works**

- Paused Deployment won’t roll new replicas until resumed.
- `kubectl set image` is the fastest way to change container image.

**Docs**

- Rolling updates: [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment)

---

## Question 23 – Configure ExternalName Service

In namespace `default`, create a Service named `external-db` that:

- Type: `ExternalName`
- Resolves to `database.prod.internal`

No selector or ports are required.

### Solution

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: external-db
  namespace: default
spec:
  type: ExternalName
  externalName: database.prod.internal
EOF
```

**Why this works**

- `ExternalName` Services simply create a DNS alias inside the cluster.
- No selector/endpoints are used.

**Docs**

- ExternalName: [https://kubernetes.io/docs/concepts/services-networking/service/#externalname](https://kubernetes.io/docs/concepts/services-networking/service/#externalname)

---

## Question 24 – Fix CronJob restart policy and backoffLimit

In namespace `default`, CronJob `hourly-report` exists with:

- Schedule: `0 * * * *`
- Container: `busybox` printing `hourly report`
- Template incorrectly configured with `restartPolicy: OnFailure` and an undesired `backoffLimit`.

Update CronJob `hourly-report` so that:

- Pods created by the Job never restart (`restartPolicy: Never`).
- The Job’s `backoffLimit` is set to `2`.

### Solution

```bash
kubectl edit cronjob hourly-report
```

Under `spec.jobTemplate.spec` ensure:

```yaml
backoffLimit: 2
template:
  spec:
    restartPolicy: Never
    containers:
      - name: report
        image: busybox
        # ...
```

Save and exit.

**Why this works**

- `backoffLimit` controls how many times a failed Job will retry.
- `restartPolicy: Never` means failed Pods won’t be restarted by the kubelet.

**Docs**

- CronJob / Job fields: [https://kubernetes.io/docs/concepts/workloads/controllers/job/](https://kubernetes.io/docs/concepts/workloads/controllers/job/)

---

## Question 25 – Fix Deployment selector/labels mismatch

On the node, file `/root/broken-app.yaml` contains a Deployment manifest for `broken-app` with a mismatch between:

- `.spec.selector.matchLabels`
- `.spec.template.metadata.labels`

Fix the manifest so that:

- The selector and template labels use the same `app` label.
- Deployment `broken-app` is successfully created.
- At least one Pod is running for this Deployment.

### Solution

Edit the file:

```bash
vi /root/broken-app.yaml
```

Correct it to something like:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fixed-app
  template:
    metadata:
      labels:
        app: fixed-app
    spec:
      containers:
        - name: web
          image: nginx
```

Apply:

```bash
kubectl apply -f /root/broken-app.yaml
kubectl rollout status deploy broken-app
```

**Why this works**

- In `apps/v1`, the selector is immutable and must match template labels.
- Once they match, the Deployment manages the Pods correctly and becomes `Available`.

**Docs**

- Deployment selectors: [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#selector](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#selector)
