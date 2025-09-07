# 🚀 CKA Practice Test

This document contains practice questions and detailed solutions for the Certified Kubernetes Administrator (CKA) exam. Each question specifies which node to connect to and what actions to perform. Follow the steps carefully as they mirror real exam scenarios.

---

## Question 1 | Contexts

**Node:** `ssh cka9412`
**File to use:** `/opt/course/1/kubeconfig`

### Task

1. Write all kubeconfig **context names** into `/opt/course/1/contexts` (one per line).
2. Write the name of the **current context** into `/opt/course/1/current-context`.
3. Write the **client-certificate** of user `account-0027` (base64-decoded) into `/opt/course/1/cert`.

---

## Question 2 | MinIO Operator, CRD Config, Helm Install

**Node:** `ssh cka7968`

### Task

1. Create Namespace `minio`.
2. Install the MinIO Operator via Helm into this Namespace. The Helm Release must be called `minio-operator`.
3. Update the Tenant CRD manifest (`/opt/course/2/minio-tenant.yaml`) to include:

   ```yaml
   features:
     enableSFTP: true
   ```

4. Apply the Tenant CRD manifest.

---

### Background Concepts

- **Helm Chart:** A collection of Kubernetes YAML templates packaged together.
- **Helm Release:** A running instance of a Helm Chart.
- **Helm Values:** Used to customize chart templates during installation.
- **Operator:** A controller that extends Kubernetes functionality using CRDs.
- **CRD (Custom Resource Definition):** Extends the Kubernetes API with custom resource types.

---

### Solution Walkthrough

#### Step 1: Create Namespace

```bash
ssh cka7968
kubectl create ns minio
```

#### Step 2: Install MinIO Operator via Helm

```bash
helm repo list
helm search repo minio/operator
helm -n minio install minio-operator minio/operator
```

Verify:

```bash
helm -n minio ls
kubectl -n minio get pod
kubectl get crd | grep minio
```

#### Step 3: Update Tenant CRD

Edit the file `/opt/course/2/minio-tenant.yaml`:

```yaml
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: tenant
  namespace: minio
spec:
  features:
    bucketDNS: false
    enableSFTP: true # Added
  image: quay.io/minio/minio:latest
  pools:
    - servers: 1
      name: pool-0
      volumesPerServer: 0
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Mi
          storageClassName: standard
  requestAutoCert: true
```

#### Step 4: Apply the Tenant Resource

```bash
kubectl apply -f /opt/course/2/minio-tenant.yaml
kubectl -n minio get tenant
```

✅ Tenant created successfully using Helm + CRD.

---

## Question 3 | Scale Down StatefulSet

**Node:** `ssh cka3962`
**Namespace:** `project-h800`

### Task

The `o3db` StatefulSet has **2 replicas**. Scale it down to **1 replica**.

---

### Solution Walkthrough

#### Step 1: Check Pods

```bash
ssh cka3962
kubectl -n project-h800 get pods | grep o3db
```

Output:

```
o3db-0   Running
o3db-1   Running
```

#### Step 2: Verify Controller

```bash
kubectl -n project-h800 get deploy,ds,sts | grep o3db
```

Confirms it’s a StatefulSet.

#### Step 3: Scale StatefulSet

```bash
kubectl -n project-h800 scale sts o3db --replicas=1
```

Verify:

```bash
kubectl -n project-h800 get sts o3db
```

Output:

```
NAME   READY   AGE
o3db   1/1     6d19h
```

✅ StatefulSet successfully scaled down.

---

# 📘 Summary

- **Q1:** Extracted context names, current context, and client-certificate from kubeconfig.
- **Q2:** Installed MinIO Operator with Helm, updated Tenant CRD, and applied it.
- **Q3:** Scaled down StatefulSet `o3db` from 2 replicas to 1.

These exercises strengthen your skills in **kubeconfig management, Helm, CRDs, and StatefulSet operations**, which are all common tasks in the CKA exam.

---

## Question 4 | Find Pods First to Be Terminated

**Node:** `ssh cka2556`
**Namespace:** `project-c13`

### Task

Check all available Pods in the Namespace `project-c13` and identify the Pods that would **likely be terminated first** if the nodes run out of CPU or memory.

Write the Pod names into:

```
/opt/course/4/pods-terminated-first.txt
```

---

### Background

- Kubernetes assigns Pods into **QoS (Quality of Service) classes**:

  - **Guaranteed** → All containers have CPU & memory requests **equal** to limits.
  - **Burstable** → Containers have requests, but not equal to limits.
  - **BestEffort** → No CPU/memory requests or limits defined.

- **Termination priority:**
  `BestEffort` Pods are killed first → then `Burstable` Pods that exceed requests → `Guaranteed` Pods are the last candidates.

---

### Solution Walkthrough

#### Step 1: Connect to Node

```bash
ssh cka2556
```

#### Step 2: Check Resource Requests

```bash
kubectl -n project-c13 describe pod | grep -A 3 -E 'Requests|^Name:'
```

Alternatively:

```bash
kubectl -n project-c13 get pod -o jsonpath="{range .items[*]} {.metadata.name}{.spec.containers[*].resources}{'\n'}"
```

This shows Pods **without CPU/memory requests**, meaning they are `BestEffort`.

#### Step 3: Verify QoS Class

```bash
kubectl get pods -n project-c13 -o jsonpath="{range .items[*]}{.metadata.name} {.status.qosClass}{'\n'}"
```

Example output:

```
c13-2x3-api-...       Burstable
c13-2x3-web-...       Burstable
c13-3cc-data-...      Burstable
c13-3cc-runner-heavy-gnxjh   BestEffort
c13-3cc-runner-heavy-przdh   BestEffort
c13-3cc-runner-heavy-wqwfz   BestEffort
```

#### Step 4: Write Answer

The following Pods are **BestEffort** (first to be terminated):

```
/opt/course/4/pods-terminated-first.txt
```

```text
c13-3cc-runner-heavy-8687d66dbb-gnxjh
c13-3cc-runner-heavy-8687d66dbb-przdh
c13-3cc-runner-heavy-8687d66dbb-wqwfz
```

---

✅ **Answer:** Pods without resource requests/limits (`BestEffort`) are terminated first under resource pressure. In this case:
`c13-3cc-runner-heavy-*`

---

## Question 5 | Kustomize Configure HPA Autoscaler

**Node:** `ssh cka5774`
**Namespaces:** `api-gateway-staging`, `api-gateway-prod`

### Task

1. Remove the `ConfigMap` **horizontal-scaling-config** completely.
2. Add an HPA named **api-gateway** for the Deployment `api-gateway`:

   - Min replicas: **2**
   - Max replicas: **4**
   - Scale at **50% average CPU utilization**

3. In **prod**, set the HPA to **max 6 replicas**.
4. Apply your changes so they are reflected in the cluster.

---

### Solution Walkthrough

#### Step 1: Connect to Node

```bash
ssh cka5774
cd /opt/course/5/api-gateway
```

#### Step 2: Remove ConfigMap

Remove `horizontal-scaling-config` from:

- `base/api-gateway.yaml`
- `staging/api-gateway.yaml`
- `prod/api-gateway.yaml`

Then delete it remotely:

```bash
kubectl -n api-gateway-staging delete cm horizontal-scaling-config
kubectl -n api-gateway-prod delete cm horizontal-scaling-config
```

#### Step 3: Add HPA in Base

Edit `base/api-gateway.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

#### Step 4: Patch for Prod

Edit `prod/api-gateway.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway
spec:
  maxReplicas: 6
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  labels:
    env: prod
```

#### Step 5: Apply Changes

```bash
kubectl kustomize staging | kubectl apply -f -
kubectl kustomize prod | kubectl apply -f -
```

Verify:

```bash
kubectl -n api-gateway-staging get hpa
kubectl -n api-gateway-prod get hpa
```

---

✅ **Answer:** Staging HPA created with `minReplicas=2`, `maxReplicas=4`. Prod HPA created with `minReplicas=2`, `maxReplicas=6`. ConfigMaps successfully removed.

---

## Question 6 | Storage, PV, PVC, Pod Volume

**Node:** `ssh cka7968`
**Namespace:** `project-t230`

### Task

1. Create a **PersistentVolume** named `safari-pv`:

   - Capacity: **2Gi**
   - AccessMode: **ReadWriteOnce**
   - `hostPath: /Volumes/Data`
   - No `storageClassName`

2. Create a **PersistentVolumeClaim** named `safari-pvc` in Namespace `project-t230`:

   - Request: **2Gi**
   - AccessMode: **ReadWriteOnce**
   - No `storageClassName`
   - It must bind to `safari-pv`.

3. Create a **Deployment** named `safari` in Namespace `project-t230`:

   - Image: **httpd:2-alpine**
   - Mount the PVC at `/tmp/safari-data`.

---

### Solution Walkthrough

#### Step 1: Create PersistentVolume

`6_pv.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: safari-pv
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/Volumes/Data"
```

```bash
kubectl apply -f 6_pv.yaml
```

---

#### Step 2: Create PersistentVolumeClaim

`6_pvc.yaml`:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: safari-pvc
  namespace: project-t230
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

```bash
kubectl apply -f 6_pvc.yaml
kubectl -n project-t230 get pv,pvc
```

Verify PVC bound:

```
persistentvolume/safari-pv   2Gi   RWO   Bound   project-t230/safari-pvc
persistentvolumeclaim/safari-pvc   Bound   safari-pv   2Gi
```

---

#### Step 3: Create Deployment With Volume

Generate and edit deployment:

```bash
kubectl -n project-t230 create deploy safari --image=httpd:2-alpine --dry-run=client -o yaml > 6_dep.yaml
```

`6_dep.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: safari
  namespace: project-t230
spec:
  replicas: 1
  selector:
    matchLabels:
      app: safari
  template:
    metadata:
      labels:
        app: safari
    spec:
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: safari-pvc
      containers:
        - name: container
          image: httpd:2-alpine
          volumeMounts:
            - name: data
              mountPath: /tmp/safari-data
```

```bash
kubectl apply -f 6_dep.yaml
```

---

#### Step 4: Verify Mount

```bash
kubectl -n project-t230 describe pod -l app=safari | grep -A2 Mounts:
```

Expected:

```
Mounts:
  /tmp/safari-data from data (rw)
```

---

✅ **Answer:** `safari-pv` created, `safari-pvc` bound, and `safari` Deployment successfully mounts the PVC at `/tmp/safari-data`.

---

## Question 7 | Node and Pod Resource Usage

**Node:** `ssh cka5774`

### Task

- Create `/opt/course/7/node.sh` to show **node** resource usage.
- Create `/opt/course/7/pod.sh` to show **pod + container** resource usage.

### Solution

Create scripts:

```bash
sudo tee /opt/course/7/node.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
kubectl top node
EOF

sudo tee /opt/course/7/pod.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
kubectl top pod --containers=true
EOF

sudo chmod +x /opt/course/7/node.sh /opt/course/7/pod.sh
```

Run:

```bash
/opt/course/7/node.sh
/opt/course/7/pod.sh
```
