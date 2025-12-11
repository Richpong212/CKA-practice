# CKAD Practice Exam – 20 Tasks (Exam Style)

The cluster is preconfigured. Use the existing resources where applicable.  
Unless otherwise specified, use namespace `default`.

---

## Question 1

Namespace `prod` contains a Deployment named `db-api` with hard-coded environment variables `USER` and `PASSWORD`.

Update the configuration to:

1. Create a Secret named `db-credentials` in namespace `prod` containing the values for `USER` and `PASSWORD`.
2. Modify Deployment `db-api` so that the container reads `USER` and `PASSWORD` from the Secret using `valueFrom.secretKeyRef`.

Do not change the Deployment name or namespace.

---

## Question 2

In namespace `default`, the following resources exist:

- Deployment `web-deploy-main`
- Service `web-svc`
- Ingress `web-bad-ingress`

The Ingress does not correctly route HTTP traffic to `web-svc`.

Reconfigure Ingress `web-bad-ingress` so that HTTP requests to path `/` are forwarded to Service `web-svc` on port `8080` using a valid `pathType`.

---

## Question 3

In namespace `default`, the following resources exist:

- Deployment `api-deployment`
- Service `api-svc` exposing port `3000`

Create an Ingress named `api-ing` in namespace `default` that:

- Routes host `api.example.com`
- Path `/`
- To Service `api-svc` on port `3000`.

Use the current stable Ingress API version.

---

## Question 4

In namespace `netpol-lab`:

- Pods `frontend`, `backend`, and `database` already exist.
- NetworkPolicies `allow-frontend-to-backend`, `allow-backend-to-db`, `deny-all`, and `allow-frontend-http` already exist.

The Pod labels do not currently match the NetworkPolicies.

Without modifying any NetworkPolicy objects, update the labels on Pods `frontend`, `backend`, and `database` so that traffic is allowed in the following chain:

`frontend` → `backend` → `database`.

---

## Question 5

In namespace `dev`, perform the following:

1. Create a Pod named `heavy-pod` with:
   - Image: `nginx`
   - CPU request: `200m`
   - CPU limit: `500m`
   - Memory request: `128Mi`
   - Memory limit: `256Mi`
2. Create a ResourceQuota named `dev-quota` that enforces:
   - Maximum number of Pods: `10`
   - Total CPU requests: `2` (cores)
   - Total memory requests: `4Gi`

Ensure both resources are created in namespace `dev`.

---

## Question 6

On the node’s filesystem, directory `/root/app` contains a valid `Dockerfile`.

Using the available container tooling:

1. Build an image named `tool:v2` using `/root/app` as the build context.
2. Save this image into the file `/root/tool.tar` as a container image archive.

Do not change the directory layout.

---

## Question 7

In namespace `default`, the following resources exist:

- Deployment `app-stable` with labels `app=app`, `version=v1`
- Service `app-service` selecting `app=app`

Create an additional Deployment named `app-canary` in namespace `default` with:

- Labels: `app=app`, `version=v2`
- Image: `nginx`
- Replicas: `1`

Ensure that both `app-stable` and `app-canary` Pods are selected by `app-service`.

---

## Question 8

In namespace `default`, the following resources exist:

- Deployment `web-app` with Pods labeled `app=web`
- Service `web-app-svc` with an incorrect selector

Update Service `web-app-svc` so that it correctly selects the Pods created by Deployment `web-app`.

Do not rename any existing resources.

---

## Question 9

In namespace `default`, create a CronJob named `backup-cron` with the following requirements:

- Schedule: every 2 minutes (`*/2 * * * *`)
- Image: `busybox`
- The container prints `backing up` to standard output.
- Pods created by the Job must not restart after completion.

Use the current stable CronJob API.

---

## Question 10

In namespace `default`, create a CronJob named `workers-batch` with the following requirements:

- Schedule: every minute (`* * * * *`)
- Image: `busybox`
- The container prints `processing` to standard output.
- Each Job created by the CronJob must be configured with:
  - `completions: 4`
  - `parallelism: 2`
  - `backoffLimit: 3`
- Pods created by the Job must not restart after completion.

Use the current stable CronJob API.

---

## Question 11

In namespace `default`, Deployment `web-deploy` exists with a container named `web` and no security context.

Update Deployment `web-deploy` so that:

- At the Pod level, the security context sets `runAsUser` to `1000`.
- At the container level for container `web`, capability `NET_ADMIN` is added.

Apply the change so that the updated Deployment rolls out successfully.

---

## Question 12

In namespace `rbac-lab`:

- ServiceAccount `wrong-sa` exists.
- Pod `audit-pod` uses ServiceAccount `wrong-sa` and runs `kubectl get pods --all-namespaces` but does not have the required permissions.

Perform the following:

1. Create a ServiceAccount named `audit-sa` in namespace `rbac-lab`.
2. Create a Role named `audit-role` in namespace `rbac-lab` that grants `get`, `list`, and `watch` on resource `pods`.
3. Create a RoleBinding named `audit-rb` in namespace `rbac-lab` that binds `audit-role` to ServiceAccount `audit-sa`.
4. Reconfigure Pod `audit-pod` to use ServiceAccount `audit-sa`.

---

## Question 13

In namespace `default`, Deployment `accounts-api` exists with a container named `accounts` that listens on container port `8080`.

Update Deployment `accounts-api` to add a readiness probe to container `accounts` with the following properties:

- HTTP GET request to path `/ready`
- Port `8080`
- `initialDelaySeconds: 5`

Ensure the Deployment is updated successfully.

---

## Question 14

In namespace `default`, Pod `livecheck` exists with a single container using image `nginx` and container port `80`.

Modify the configuration so that Pod `livecheck` has a liveness probe on the container with:

- HTTP GET request to path `/health`
- Port `80`
- `initialDelaySeconds: 5`

If direct editing is not possible, you may delete and recreate Pod `livecheck` with the required liveness probe.

---

## Question 15

In namespace `default`, Deployment `payments` has undergone a rollout to an invalid or non-working image.

Perform the following:

1. Roll back Deployment `payments` to the previous working revision.
2. Verify that the rollout has completed successfully and that the Deployment is using the working image.

Do not create a new Deployment.

---

## Question 16

On the node’s filesystem, file `/root/old.yaml` contains a Deployment manifest using a deprecated API version and an invalid rolling update configuration.

Update `/root/old.yaml` so that:

- It uses `apiVersion: apps/v1`.
- It specifies a valid `.spec.selector` that matches the Pod template labels.
- The rolling update strategy under `.spec.strategy` is valid (for example, valid values for `maxSurge` and `maxUnavailable`).

Apply the updated manifest so that Deployment `old-deploy` is created successfully.

---

## Question 17

In namespace `default`, Pod `broken-init` exists with:

- Image: `busybox`
- Command: `/app/start.sh`

The Pod fails because `/app/start.sh` does not exist.

Recreate Pod `broken-init` so that:

- It uses an `emptyDir` volume mounted at `/app` for both:
  - An init container that:
    - Creates the file `/app/start.sh` containing `echo start app`
    - Marks `/app/start.sh` as executable
  - The main container that:
    - Executes `/app/start.sh` as its command

Ensure the recreated Pod reaches the `Running` state.

---

## Question 18

In namespace `netpol-lab`:

- Pod `auth` currently has labels `role=wrong-auth` and `env=dev`.
- Pod `db` has labels `role=db` and `env=prod`.
- NetworkPolicies `allow-auth-ingress` and `allow-db-egress` select Pods with `role=auth` and `env=prod`.

Without modifying any NetworkPolicy objects, update the labels on Pod `auth` so that it matches the Pod selectors used by `allow-auth-ingress` and `allow-db-egress`.

---

## Question 19

In namespace `default`, the following resources exist:

- Service `path-test-svc`
- Deployment `path-test-deploy`
- Ingress `bad-path-ingress` with an invalid `pathType` for the HTTP path.

Update Ingress `bad-path-ingress` so that its HTTP path configuration uses a valid `pathType` (for example, `Prefix`) for path `/`, and continues to route traffic to Service `path-test-svc` on port `80`.

---

## Question 20

In namespace `default`, Deployment `backend` exists with a container named `backend` using image `nginx:1.25`.

Perform the following sequence:

1. Pause the rollout of Deployment `backend`.
2. While the rollout is paused, update the image for container `backend` to a newer valid image tag (for example, `nginx:1.27`).
3. Resume the rollout of Deployment `backend`.
4. Verify that the rollout completes successfully and that the new image is in use.

---
