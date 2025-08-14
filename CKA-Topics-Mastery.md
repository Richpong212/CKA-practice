# CKA Sure‑Banger Practice Pack

> If you can complete these tasks quickly from the CLI (without Googling), you’ll be rock‑solid across every CKA domain.

---

## How to Use This Pack

1. **Speed‑run each task** twice: once declarative (YAML), once imperative (`kubectl create/run/expose/patch`).
2. **Verify fast** after each: `kubectl get/describe`, `kubectl logs`, `kubectl events`, and a quick `curl`/`wget` from a temp pod.
3. **Drill pitfalls:** wrong selectors/ports, immutable fields (Pods), NP blocks, DNS Corefile typos, resource requests too high.
4. **Timing:** Aim \~45–60 min per domain section.
5. **Aliases (optional):** `alias k=kubectl` and use `-o wide`, `-n <ns>` liberally.

---

## Quick Reference

- Create temp curl pod:

  ```bash
  kubectl run curl --rm -it --image=radial/busyboxplus:curl --restart=Never -- /bin/sh
  ```

- Tail pod logs (including previous):

  ```bash
  kubectl logs <pod> --tail=100
  kubectl logs <pod> --previous --tail=100
  ```

- Watch events:

  ```bash
  kubectl get events --sort-by=.lastTimestamp -A
  ```

---

## Storage (10%)

### S1. Static PV/PVC + Pod mount (hostPath)

**Task:** Create a 1Gi `PersistentVolume` named `pv-host` (hostPath `/opt/data`) with `ReadWriteOnce`, `Retain`. Bind PVC `pvc-host` (1Gi, RWO), mount at `/data` in a busybox pod, write/read a file.

**Solution sketch:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-host
spec:
  capacity:
    storage: 1Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /opt/data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-host
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: bb
spec:
  containers:
    - name: bb
      image: busybox
      command: ["sh", "-c", "sleep 3600"]
      volumeMounts:
        - name: v
          mountPath: /data
  volumes:
    - name: v
      persistentVolumeClaim:
        claimName: pvc-host
```

```bash
kubectl apply -f s1.yaml
kubectl exec bb -- sh -c 'echo hi > /data/ok && cat /data/ok'
```

### S2. Default StorageClass & dynamic PVC

**Task:** Mark an existing SC (e.g., `standard`) as default; provision a 2Gi PVC that binds dynamically.

```bash
kubectl patch storageclass standard \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dyn-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Gi
YAML
kubectl get pvc dyn-pvc
```

### S3. PVC resize

**Task:** Expand `dyn-pvc` from 2Gi to 4Gi; verify capacity after pod remount or filesystem expansion.

```bash
kubectl patch pvc dyn-pvc -p '{"spec":{"resources":{"requests":{"storage":"4Gi"}}}}'
kubectl get pvc dyn-pvc -w
```

### S4. Reclaim policy exercise

**Task:** Using your CSI default SC (Delete policy), create a PVC, bind/mount, then delete the PVC and confirm PV is deleted automatically.

### S5. AccessModes contention (RWO)

**Task:** Try mounting the same RWO PVC into two running pods and observe scheduling/event messages. Explain why only one attachment is allowed.

### S6. RWX validation (if available)

**Task:** Using an RWX‑capable SC (e.g., NFS/CEPH), mount the same PVC into two pods; write from one, read from the other.

---

## Troubleshooting (30%)

### T1. CrashLoopBackOff (bad command)

**Task:** Deployment `app` is crashlooping due to wrong command. Fix to `python3 -m http.server 8080`, keep labels, zero downtime with ≥1 replica.

```bash
kubectl -n default set image deploy/app app=python:3.12
kubectl -n default patch deploy app --type=json -p='[
 {"op":"add","path":"/spec/template/spec/containers/0/command",
  "value":["sh","-c","python3 -m http.server 8080"]}
]'
kubectl rollout status deploy/app
```

### T2. Pod Pending (requests too high)

**Task:** Pod `heavy` is Pending; lower requests to `100m` CPU and `100Mi` memory (recreate if needed because Pod specs are largely immutable).

```bash
kubectl get pod heavy -o yaml > /tmp/heavy.yaml
# Edit resources.requests, then:
kubectl delete pod heavy && kubectl apply -f /tmp/heavy.yaml
```

### T3. Service 503 (selector mismatch)

**Task:** `svc web` targets `app=web` but pods have `app=webapp`. Fix selector and verify traffic.

```bash
kubectl patch svc web -p '{"spec":{"selector":{"app":"webapp"}}}'
kubectl run curl --rm -it --image=radial/busyboxplus:curl -- curl -sS web:80
```

### T4. NetworkPolicy block

**Task:** `client` in ns `a` cannot reach `server` in ns `b`. Identify offending NP and permit traffic from namespace `a`.

```bash
kubectl get netpol -A
kubectl describe netpol -n b
# Patch or create an NP allowing ingress from ns a via namespaceSelector.
```

### T5. CoreDNS broken

**Task:** DNS lookups failing. Inspect CoreDNS pods and ConfigMap; roll back bad changes and restart.

```bash
kubectl -n kube-system get po -l k8s-app=kube-dns
kubectl -n kube-system get cm coredns -o yaml
kubectl -n kube-system rollout restart deploy coredns
```

### T6. Node NotReady (kubelet)

**Task:** Diagnose with `journalctl -u kubelet`; fix certs/config/CNI dir as appropriate and recover node to `Ready`.

### T7. Logs (current & previous)

```bash
kubectl logs api-xyz -c api --tail=100
kubectl logs api-xyz -c api --previous --tail=100
```

### T8. HPA not scaling

**Task:** Confirm metrics‑server, describe HPA, generate load, observe scale‑out.

```bash
kubectl get apiservice | grep metrics
kubectl describe hpa myapp
kubectl run load --image=busybox -- sh -c 'while true; do wget -qO- http://myapp; done'
```

---

## Workloads & Scheduling (15%)

### W1. Rolling update + rollback

```bash
kubectl set image deploy/rollme app=nginx:bogus
kubectl rollout status deploy/rollme
kubectl rollout undo deploy/rollme
kubectl rollout history deploy/rollme
```

### W2. ConfigMap & Secret injection

```bash
kubectl create cm app-cm --from-literal=feature=on
kubectl create secret generic db-sec \
  --from-literal=user=alice --from-literal=pass=s3cr3t
# Mount the CM as a volume and use envFrom the Secret in a Pod/Deployment.
```

### W3. HPA CPU scaling

```bash
kubectl autoscale deploy web --min=2 --max=6 --cpu-percent=60
```

### W4. Scheduling controls (anti‑affinity & tolerations)

```yaml
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels: { app: api }
      topologyKey: kubernetes.io/hostname

# Tolerate node taint workload=backend:NoSchedule
# (add under the Pod spec)
tolerations:
  - key: workload
    operator: Equal
    value: backend
    effect: NoSchedule
```

### W5. Self‑healing primitives (probes)

```yaml
readinessProbe:
  httpGet: { path: /healthz, port: 8080 }
  initialDelaySeconds: 5
  periodSeconds: 5
livenessProbe:
  exec: { command: ["sh", "-c", "pgrep myproc"] }
  initialDelaySeconds: 10
  periodSeconds: 10
```

### W6. PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels: { app: api }
```

---

## Cluster Architecture, Installation & Configuration (25%)

### C1. RBAC: read Pods cluster‑wide (ServiceAccount)

```bash
kubectl create sa auditor -n default
kubectl create clusterrole pod-reader --verb=get,list,watch --resource=pods
kubectl create clusterrolebinding auditor-pods \
  --clusterrole=pod-reader --serviceaccount=default:auditor
```

### C2. RBAC: namespaced write to Deployments

```bash
kubectl create ns team-a
kubectl -n team-a create sa deployer
kubectl -n team-a create role deploy-writer \
  --verb=create,update,patch --resource=deployments
kubectl -n team-a create rolebinding deploy-writer-binding \
  --role=deploy-writer --serviceaccount=team-a:deployer
```

### C3. kubeadm join token (add node)

```bash
sudo kubeadm token create --print-join-command --ttl 24h
```

### C4. etcd snapshot & restore (single‑node control plane)

**Snapshot:**

```bash
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/etcd.db
```

**Restore (outline):** restore into a new data dir, update static pod manifest or kubeadm config to point to it, then restart the control plane components.

### C5. Helm install + values override (metrics‑server example)

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
  --set args='{--kubelet-insecure-tls,--kubelet-preferred-address-types=InternalIP}'
kubectl top nodes
```

### C6. Kustomize: set image + env overlay

`overlays/prod/kustomization.yaml`:

```yaml
resources: ["../../base"]
images:
  - name: myrepo/app
    newTag: "2.0.1"
patches:
  - target: { kind: Deployment, name: app }
    patch: |
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value: {name: ENV, value: "prod"}
```

```bash
kubectl apply -k overlays/prod
```

### C7. Extension interfaces (identify CRI, CNI, CSI)

```bash
# CRI
crictl info | jq '.config.runtimeType'
# CNI
ls /etc/cni/net.d
kubectl -n kube-system get ds | grep -i 'calico\|flannel\|cilium'
# CSI
kubectl get csidrivers
```

### C8. CRDs & Operators

**Task:** List CRDs, pick one (e.g., Prometheus), create a minimal CR, verify operator reconciles it.

```bash
kubectl get crd
kubectl api-resources | grep -i prometheus
# Apply CR per operator docs and check status conditions
```

---

## Services & Networking (20%)

### N1. Pod‑to‑Pod/Service connectivity

```bash
kubectl run s1 --image=nginx --port=80
kubectl expose pod s1 --port=80 --name s1
kubectl run t1 --image=busybox --restart=Never -- sh -c 'sleep 3600'
kubectl exec t1 -- wget -qO- s1
```

### N2. NodePort service

```bash
kubectl patch svc s1 -p '{"spec":{"type":"NodePort","nodePort":30080}}'
# curl a nodeIP:30080
```

### N3. ExternalName service

```yaml
apiVersion: v1
kind: Service
metadata: { name: ext-google }
spec:
  type: ExternalName
  externalName: www.google.com
```

### N4. Headless Service + Endpoints

```yaml
apiVersion: v1
kind: Service
metadata: { name: db }
spec:
  clusterIP: None
  ports: [{ port: 5432, targetPort: 5432 }]
---
apiVersion: v1
kind: Endpoints
metadata: { name: db }
subsets:
  - addresses: [{ ip: 10.1.0.10 }, { ip: 10.1.0.11 }]
    ports: [{ port: 5432 }]
```

### N5. Ingress (NGINX, TLS)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ing
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
    - hosts: [example.com]
      secretName: web-tls
  rules:
    - host: example.com
      http:
        paths:
          - path: /app
            pathType: Prefix
            backend:
              service:
                name: web
                port: { number: 80 }
```

### N6. Gateway API (if controller present)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata: { name: shared-gw }
spec:
  gatewayClassName: nginx
  listeners:
    - name: http
      port: 80
      protocol: HTTP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: { name: api-route }
spec:
  parentRefs: [{ name: shared-gw }]
  rules:
    - matches: [{ path: { type: PathPrefix, value: /api } }]
      backendRefs: [{ name: api-svc, port: 80 }]
```

### N7. NetworkPolicy allow‑only selected namespace

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-allow-api
  namespace: db
spec:
  podSelector: { matchLabels: { app: db } }
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: { matchLabels: { name: api } }
```

### N8. CoreDNS stub domain

```bash
kubectl -n kube-system edit cm coredns
# Add:
# corp.local:53 {
#   errors
#   cache 30
#   forward . 10.10.0.2
# }
kubectl -n kube-system rollout restart deploy coredns
```

---

## Self‑Grading Checklist

- [ ] Create/bind/resize PVCs; explain reclaim policies without docs.
- [ ] Diagnose CrashLoop, Pending, NotReady, broken DNS, NP blocks in < 5 minutes.
- [ ] Perform rolling updates/undo, HPA, PDB, probes, (anti)affinity from memory.
- [ ] Author ClusterRole/RoleBinding correctly on first try.
- [ ] Snapshot/restore etcd and list exact flags/paths needed.
- [ ] Install/patch Helm charts and apply Kustomize overlays confidently.
- [ ] Create ClusterIP/NodePort/Ingress/Gateway and verify with a curl pod.
- [ ] Write deny‑by‑default NP and then allow precisely what’s needed.

---

## Pro Tips

- Favor `kubectl explain <kind> --recursive | less` to discover fields quickly.
- Use `kubectl get <kind> -o yaml > file.yaml` to capture manifests for edit‑and‑recreate flows.
- For Services, always cross‑check **selector labels** and **targetPort/port**.
- For HPA, ensure `metrics-server` is healthy (`kubectl top nodes/pods`).
- For DNS, check CoreDNS logs and ConfigMap, then rollout restart.

---

**Good luck!** Keep this README open as a practice checklist; once you can do it all fast, you’re exam‑ready.
