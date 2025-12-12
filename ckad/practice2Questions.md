## Exercise 1 — Ingress host+path to backend (curl returns NotFound)

**Context:** Namespace `inglab`.
There is a Deployment `backend`, Service `backend-svc`, and an Ingress `app-ing` that is misconfigured.

**Task:** Fix `app-ing` so that:

- host = `example.com`
- path = `/`
- pathType = `Prefix`
- routes to Service `backend-svc` port `80`

### Solution

```bash
kubectl -n inglab edit ingress app-ing
```

Set:

```yaml
spec:
  rules:
    - host: example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-svc
                port:
                  number: 80
```

### Why

Ingress only forwards when the **host + path** match AND the backend service name/port is correct.
A wrong service name or wrong path is the most common “curl -> 404/NotFound” cause.

Link:

- [https://kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

## Exercise 2 — Fix Service selector fast

**Context:** Namespace `svclab`.
`web-svc` exists but points to no pods.

**Task:** Fix `web-svc` so it selects pods from Deployment `web`.

### Solution

Check pod labels:

```bash
kubectl -n svclab get pods --show-labels
```

Fix service selector:

```bash
kubectl -n svclab edit svc web-svc
```

Set:

```yaml
spec:
  selector:
    app: web
```

### Why

Services route to pods only through **label selectors**.
If selectors don’t match any pods, the service has **zero endpoints**.

Link:

- [https://kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/)

---

## Exercise 3 — Canary 20% + max 10 pods (same deployment shape)

**Context:** Namespace `canarylab`.
Two Deployments exist: `api-stable` and `api-canary`. A Service `api-svc` selects `app=api`.

**Task:** Configure canary so:

- total pods = 10
- 20% traffic to canary
- use same “shape” as stable (same container, same service, only version label differs)

**Expected model:** stable=8, canary=2.

### Solution

```bash
kubectl -n canarylab scale deploy api-stable --replicas=8
kubectl -n canarylab scale deploy api-canary --replicas=2
```

### Why

With a single Service selecting both sets, kube-proxy load balances across endpoints.
**2/10 endpoints = ~20%** traffic to canary in a typical round-robin-ish distribution.

Link:

- [https://kubernetes.io/docs/concepts/workloads/controllers/deployment/](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

## Exercise 4 — RBAC (from logs) fix Deployment SA + permissions to list pods

**Context:** Namespace `rbaclab`.
Deployment `audit-agent` logs show “forbidden” when listing pods.

**Task:** Create:

- ServiceAccount `audit-sa`
- Role `audit-role` allowing `get,list,watch` on `pods`
- RoleBinding `audit-rb` binding role to `audit-sa`
- Update `audit-agent` Deployment to use `audit-sa`

### Solution

Read logs:

```bash
kubectl -n rbaclab logs deploy/audit-agent --tail=20
```

Create SA:

```bash
kubectl -n rbaclab create sa audit-sa
```

Create Role:

```bash
kubectl -n rbaclab create role audit-role --verb=get,list,watch --resource=pods
```

Bind:

```bash
kubectl -n rbaclab create rolebinding audit-rb --role=audit-role --serviceaccount=rbaclab:audit-sa
```

Patch deployment SA:

```bash
kubectl -n rbaclab patch deploy audit-agent -p '{"spec":{"template":{"spec":{"serviceAccountName":"audit-sa"}}}}'
```

### Why

The error message in logs tells you exactly what resource/verb is missing.
Fix is always: **SA + Role + RoleBinding + make workload use the SA**.

Link:

- [https://kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## Exercise 5 — RBAC #2 (configmaps) + patch Pod SA

**Context:** Namespace `rbaclab`.
Pod `inspector` tries `kubectl get configmaps` and fails.

**Task:** Create:

- SA `inspector-sa`
- Role `inspector-role` allowing `get,list` on `configmaps`
- RoleBinding `inspector-rb`
- Update Pod `inspector` to use `inspector-sa`

### Solution

Create SA + Role + RB:

```bash
kubectl -n rbaclab create sa inspector-sa
kubectl -n rbaclab create role inspector-role --verb=get,list --resource=configmaps
kubectl -n rbaclab create rolebinding inspector-rb --role=inspector-role --serviceaccount=rbaclab:inspector-sa
```

**Pod SA cannot be edited in-place (immutable-ish).** Recreate:

```bash
kubectl -n rbaclab get pod inspector -o yaml > /tmp/inspector.yaml
kubectl -n rbaclab delete pod inspector
sed -i 's/serviceAccountName: wrong-sa/serviceAccountName: inspector-sa/' /tmp/inspector.yaml
kubectl -n rbaclab apply -f /tmp/inspector.yaml
```

### Why

Pods can’t be updated to add/remove containers and some fields are immutable.
For CKAD, fastest is: **export yaml → delete → apply**.

Link:

- [https://kubernetes.io/docs/concepts/workloads/pods/](https://kubernetes.io/docs/concepts/workloads/pods/)

---

## Exercise 6 — NetworkPolicy: do not edit policies, only fix labels (including multi-label)

**Context:** Namespace `netlab`.
Existing policies:

- deny-all
- allow frontend -> backend (expects role=frontend / role=backend)
- allow backend -> db (expects role=backend / role=db)

Pods have wrong role labels. `newpod` must talk to both frontend and db, and must keep multiple labels.

**Task:**

- frontend role=frontend
- backend role=backend
- db role=db
- newpod: role=frontend AND access=db (two labels)

### Solution

Fix labels (overwrite role):

```bash
kubectl -n netlab label pod frontend role=frontend --overwrite
kubectl -n netlab label pod backend  role=backend  --overwrite
kubectl -n netlab label pod db      role=db       --overwrite
```

Add / overwrite multi labels on newpod:

```bash
kubectl -n netlab label pod newpod role=frontend access=db --overwrite
```

### Why

NetworkPolicies select pods by labels. If you change policies, you waste time.
Most exam variants explicitly want you to **change labels only**.

Link:

- [https://kubernetes.io/docs/concepts/services-networking/network-policies/](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

---

## Exercise 7 — CronJob must exit after ~8 seconds WITHOUT sleep, test manually

**Context:** Namespace `cronlab`.
CronJob `quick-exit` currently loops forever.

**Task:**

- Update the CronJob so the container exits after about 8 seconds (no `sleep`)
- Manually test by running a Job from the CronJob named `quick-exit-manual`
- Verify it completes

### Solution

Edit CronJob:

```bash
kubectl -n cronlab edit cronjob quick-exit
```

Set container to a **SECONDS** busy-loop:

```yaml
args:
  - |
    start=$SECONDS
    while [ $((SECONDS-start)) -lt 8 ]; do :; done
    echo "done after ~8s"
    exit 0
```

Manual test (create Job from CronJob):

```bash
kubectl -n cronlab create job --from=cronjob/quick-exit quick-exit-manual
kubectl -n cronlab wait --for=condition=complete job/quick-exit-manual --timeout=60s
kubectl -n cronlab logs job/quick-exit-manual
```

### Why

CronJobs are schedules; the real thing that runs is a Job.
Manual trigger is a must-have trick for the exam.

Link:

- [https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)

---

## Exercise 8 — Fix invalid Ingress manifest and apply it

**Context:** File: `~/ckad-mock10/broken-ingress.yaml`
It contains invalid `pathType`.

**Task:** Fix it to a valid pathType (use `Prefix`) and apply.

### Solution

```bash
sed -i 's/pathType: InvalidType/pathType: Prefix/' ~/ckad-mock10/broken-ingress.yaml
kubectl apply -f ~/ckad-mock10/broken-ingress.yaml
```

### Why

Ingress pathType must be one of: Prefix, Exact, ImplementationSpecific.
Invalid pathType prevents creation.

Link:

- [https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types](https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types)

---

## Exercise 9 — LimitRange trap: halve limits + add resources to Deployment

**Context:** Namespace `resourcelab`
LimitRange `dev-limits` exists:

- request cpu 400m / mem 256Mi
- limit cpu 800m / mem 512Mi

**Task:**

- Halve them to: 200m/128Mi and 400m/256Mi
- Add explicit requests/limits to Deployment `payments`

### Solution

Edit LimitRange:

```bash
kubectl -n resourcelab edit limitrange dev-limits
```

Set:

- defaultRequest cpu 200m, mem 128Mi
- default cpu 400m, mem 256Mi

Add Deployment resources:

```bash
kubectl -n resourcelab set resources deploy/payments --requests=cpu=200m,memory=128Mi --limits=cpu=400m,memory=256Mi
```

### Why

If you only change Deployment but forget LimitRange (or vice versa), pods may still be blocked or auto-defaulted.

Link:

- [https://kubernetes.io/docs/concepts/policy/limit-range/](https://kubernetes.io/docs/concepts/policy/limit-range/)

---

## Exercise 10 — ResourceQuota trap: halve requests + enforce limits=2x requests

**Context:** Namespace `resourcelab`
ResourceQuota `team-quota` has:

- requests.cpu 2, requests.memory 2Gi
- limits.cpu 4, limits.memory 4Gi

**Task:**

- Halve requests to: requests.cpu=1, requests.memory=1Gi
- Update Deployment `report-api` resources so limits are exactly 2x requests

### Solution

Edit quota:

```bash
kubectl -n resourcelab edit resourcequota team-quota
```

Set:

- requests.cpu: "1"
- requests.memory: "1Gi"

Set deployment resources (fast safe pair):

```bash
kubectl -n resourcelab set resources deploy/report-api \
  --requests=cpu=250m,memory=128Mi \
  --limits=cpu=500m,memory=256Mi
```

### Why

Quota restricts totals, while per-pod requests/limits must align with requirements.
The “2x rule” is the classic scoring trick.

Link:

- [https://kubernetes.io/docs/concepts/policy/resource-quotas/](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

---

## Docker Practice (extra, not checked here but exam-common)

Build/tag/save to a specific location:

```bash
cd ~/ckad-mock10/api-image
docker build -t api-app:2.1 .
docker save -o ~/ckad-mock10/api-app_2.1.tar api-app:2.1
```

(Exam typically wants a tar file output.)
Link:

- [https://docs.docker.com/engine/reference/commandline/save/](https://docs.docker.com/engine/reference/commandline/save/)

```

---

## What you need to change in your current “check” if anything changed?
For these new files: **No** — `check.sh` already matches the environment created by `prep.sh`.

---

If you want, I can also add a **bonus 11th exercise** that mimics your “Ingress example.com/path” case with a second path rule and a second service (that’s a very common CKAD variant).
```
