# ✅ **CKAD Practice Exam – 25 Scenario-Based Tasks (2025 Edition)**

_Cluster is preconfigured. Use existing resources where applicable.
Unless otherwise specified, work in namespace `default`._

---

# **CKAD – Q01: Convert Hardcoded Env Vars into a Secret and Update the Deployment**

A Deployment named **billing-api** exists in namespace `default`. The Pod specification contains two hardcoded environment variables:

- `DB_USER=admin`
- `DB_PASS=SuperSecret123`

Storing sensitive information directly in environment variables violates security best practices, and the Deployment must be updated.

**Task:**

1. Create a Secret named `billing-secret` containing keys `DB_USER` and `DB_PASS` with their respective values.
2. Patch or edit the Deployment so that the Pod no longer defines plaintext env vars and instead loads them using `valueFrom.secretKeyRef`.
3. Ensure the updated Deployment rolls out successfully and Pods use the Secret-based environment variables.

---

# **CKAD – Q02: Fix a Broken Ingress That Routes to the Wrong Service and Port**

An Ingress named **store-ingress** exists. Requests to `/shop` return a 502 error.

Upon inspecting the Ingress, you observe:

- The service name is incorrect.
- The service port is referencing a non-existent port.
- The pathType is invalid for the current Kubernetes API version.

A valid Service named `store-svc` exists, serving on port `8080`.

**Task:**

1. Correct the Ingress rules so that path `/shop` (pathType: `Prefix`) forwards traffic to `store-svc:8080`.
2. Save and apply the configuration so that the Ingress is functional.

---

# **CKAD – Q03: Create a Host-Based Ingress for an Internal API**

A Deployment named **internal-api** exposes port `3000`. A Service named `internal-api-svc` selects it correctly.

The application team wants external access using hostname:
`internal.company.local`.

**Task:**

Create an Ingress named `internal-api-ingress` that:

- Accepts traffic for host `internal.company.local`.
- Forwards `/` to service `internal-api-svc` on port `3000`.
- Uses the stable Ingress API.

---

# **CKAD – Q04: Repair Pod Authorization Errors by Applying Correct RBAC**

In namespace `meta`, a Deployment named **dev-deployment** produces the following log error:

> Error from server (Forbidden): deployments.apps is forbidden:
> User "system:serviceaccount:meta:default" cannot list resource "deployments" in API group "apps" in the namespace "meta".

This indicates the running Pod lacks RBAC permissions for querying Deployments.

**Task:**

1. Create a ServiceAccount named `dev-sa` in namespace `meta`.
2. Create a Role `dev-deploy-role` in namespace `meta` permitting verbs `get`, `list`, `watch` on resource `deployments`.
3. Create a RoleBinding `dev-deploy-rb` binding the Role to the ServiceAccount.
4. Update `dev-deployment` to use the new ServiceAccount.
5. Ensure new Pods no longer log the error.

---

# **CKAD – Q05: Pod Failing Due to Missing File – Use Init Container & emptyDir**

A Pod named **startup-pod** is failing with:

> /app/start.sh: No such file or directory

You inspect the manifest and confirm:

- The main container expects file `/app/start.sh`.
- The file is not present inside the image.
- An init process must generate it before startup.

**Task:**

Recreate `startup-pod` with:

1. An `emptyDir` volume mounted at `/app`.
2. An initContainer that:

   - Writes executable script `/app/start.sh` containing `echo service started`.

3. A main container that executes `/app/start.sh`.
4. Ensure the Pod reaches the `Running` state.

---

# **CKAD – Q06: Build, Tag, and Export a Docker Image (OCI Format)**

A directory `/root/api-app` contains a valid Dockerfile.

**Task:**

1. Build an image named `api-app:2.1` using the directory as the context.
2. Save the built image in **OCI format** to `/root/api-app.tar`.
3. Do NOT push to any registry.

---

# **CKAD – Q07: Apply Pod Resource Requests + Namespace ResourceQuota**

In namespace `dev`, application Pods must not exceed allocated cluster resources.

**Task:**

1. Create a Pod named `resource-pod` using image `nginx` with:

   - CPU request: `200m`, limit: `500m`
   - Memory request: `128Mi`, limit: `256Mi`

2. Create a ResourceQuota named `dev-quota` enforcing:

   - Max Pods: `10`
   - Total CPU requests: `2`
   - Total Memory requests: `4Gi`

---

# **CKAD – Q08: Fix Deployment Using Deprecated API Version**

A manifest located at `/root/old.yaml` contains:

- Deprecated API version for Deployment
- Missing `.spec.selector`
- Invalid values for `maxSurge` or `maxUnavailable`

**Task:**

1. Modify the manifest so it uses `apps/v1`.
2. Add a valid `.spec.selector` matching Pod labels.
3. Correct the deployment strategy to valid values.
4. Apply the Deployment successfully.

---

# **CKAD – Q09: Create a Canary Deployment for Live Traffic Testing**

A Deployment named `app-stable` exists with label `version=v1`.
A Service named `app-svc` routes traffic to Pods labeled `app=core`.

**Task:**

Create a canary Deployment `app-canary` that:

- Uses labels `app=core`, `version=v2`
- Runs image `nginx`
- Has 1 replica
- Ensures the Service `app-svc` load balances across both Deployments

---

# **CKAD – Q10: Fix Broken Service Selector Mismatch**

A Deployment named `web-app` creates Pods labeled `app=webapp`.
A Service named `web-app-svc` currently fails to route traffic.

You discover the Service selector does not match the Pod labels.

**Task:**

Correct the Service selector so that it correctly selects the Deployment’s Pods.

---

# **CKAD – Q11: Configure a Liveness Probe on an Existing Pod**

A Pod named `healthz` exists, running `nginx` on port `80`.
It restarts because Kubernetes cannot detect liveness correctly.

**Task:**

Add a liveness probe:

- HTTP GET `/healthz`
- Port `80`
- initialDelaySeconds: `5`

If the Pod cannot be modified in place, delete and recreate it.

---

# **CKAD – Q12: Add a Readiness Probe to a Deployment (Your Exam Weakness)**

Deployment `shop-api` exposes container port `8080`.

**Task:**

Add a readinessProbe:

- HTTP GET `/ready`
- Port `8080`
- initialDelaySeconds: 5

Apply changes so that the Deployment successfully rolls out.

---

# **CKAD – Q13: Create a CronJob with Completions and Backoff Limit**

The operations team needs a periodic worker.

**Task:**

Create a CronJob named `metrics-job` that:

- Runs every **1 minute**
- Uses image `busybox`
- Executes command: `echo collecting`
- Job template must set:

  - completions: 4
  - parallelism: 2
  - backoffLimit: 3

- restartPolicy: Never

---

# **CKAD – Q14: ServiceAccount Fix Based on Pod Logs**

A Pod named `audit-runner` executes:

```
kubectl get pods --all-namespaces
```

But the logs show:

> pods is forbidden: User "system:serviceaccount:default:wrong-sa" cannot list resource "pods"

**Task:**

1. Create a new service account `audit-sa`.
2. Create Role `audit-role` allowing `get`, `list`, `watch` on Pods.
3. Bind Role → ServiceAccount using `RoleBinding audit-rb`.
4. Modify Pod `audit-runner` to use `audit-sa`.

---

# **CKAD – Q15: Capture Logs of a Pod into Node Filesystem**

A manifest `/opt/winter/winter.yaml` defines Pod `winter`. It is already deployed.

**Task:**

1. Retrieve logs from the running Pod.
2. Write them into file `/opt/winter/logs.txt` on the node.
3. Ensure the Pod remains running.

---

# **CKAD – Q16: Identify the Pod Consuming the Most CPU**

In namespace `cpu-load`, several Pods generate CPU stress.

**Task:**

1. Identify the Pod consuming the most CPU using Metrics API.
2. Write ONLY the Pod name to:
   `/opt/winter/highest.txt`.

---

# **CKAD – Q17: Create NodePort Service for an Existing Deployment**

A Deployment named `video-api` exposes port `9090`.

**Task:**

Create a Service named `video-svc`:

- Type: NodePort
- TargetPort: 9090
- Selector must match Deployment Pods
- Expose port `80` externally

---

# **CKAD – Q18: Fix Broken Ingress PathType**

An Ingress named `client-ingress` fails with an API validation error:

> Invalid value for pathType

**Task:**

1. Update Ingress to use a valid `pathType: Prefix`
2. Ensure `/` maps to service `client-svc:80`

---

# **CKAD – Q19: Apply SecurityContext on Deployment (runAsUser + Capabilities)**

A Deployment named `syncer` must follow internal security policies.

**Task:**

1. At Pod level: `runAsUser: 1000`
2. At container level: add capability `NET_ADMIN`
3. Apply and validate rollout

---

# **CKAD – Q20: Create Pod Running Redis 3.2 with Exposed Port**

In namespace `cachelayer`, create a Pod named `redis32`:

- Image: `redis:3.2`
- Expose port `6379`
- Keep running after startup

---

# **CKAD – Q21: Combine Two Existing NetworkPolicies by Fixing Pod Labels**

Namespace `netpol-chain` contains:

- Pods: `frontend`, `backend`, `database`
- NetworkPolicies:

  - `allow-frontend-to-backend`
  - `allow-backend-to-db`
  - `deny-all`

Policies are correct, **but Pod labels do not match policy selectors**.

**Task:**

Modify Pod labels only (not policies) so that:

`frontend → backend → database` communication becomes allowed.

---

# **CKAD – Q22: Resume Paused Rollout & Apply New Image**

Deployment `dashboard` was manually paused during a previous rollout.
Changing the image now results in:

> rollout paused

**Task:**

1. Update the Deployment to use image `nginx:1.25`.
2. Resume the rollout.
3. Verify Pods update successfully.

---

# **CKAD – Q23: Create Service of Type ExternalName**

Team wants to reference an external database service.

**Task:**

Create a Service named `external-db`:

- Type: ExternalName
- externalName: `database.prod.internal`

---

# **CKAD – Q24: Fix Misconfigured CronJob (Wrong Restart Policy)**

A CronJob named `hourly-report` exists but keeps restarting failed Pods indefinitely.

**Task:**

Update the Job template to use:

- restartPolicy: Never
- backoffLimit: 2

Ensure successful job behavior.

---

# **CKAD – Q25: Deployment with Missing Selector & Wrong Labels**

A Deployment manifest at `/root/broken-app.yaml` fails to apply with:

> selector does not match template labels

**Task:**

1. Correct `.spec.selector.matchLabels`
2. Correct `.spec.template.metadata.labels`
3. Apply the Deployment so that Pods are created successfully.
