For this question, please set the context to cluster2 by running:

kubectl config use-context cluster2

### Q3

In the ckad-job namespace, create a cronjob named simple-node-job to run every 30 minutes to list all the running processes inside a container that used node image (the command needs to be run in a shell).

In Unix-based operating systems, ps -eaf can be use to list all the running processes.

Solution
Create a YAML file with the content as below:

apiVersion: batch/v1
kind: CronJob
metadata:
name: simple-node-job
namespace: ckad-job
spec:
schedule: "_/30 _ \* \* \*"
jobTemplate:
spec:
template:
spec:
containers: - name: simple-node-job
image: node
imagePullPolicy: IfNotPresent
command: - /bin/sh - -c - ps -eaf
restartPolicy: OnFailure

Then use kubectl apply -f file_name.yaml to create the required object.

Details

Is cronjob simple-node-job created?

Is the container image node?

Does cronjob run ps -eaf command?

Does cronjob run every 30 minutes?

###

---

Task
SECTION: APPLICATION DEPLOYMENT

For this question, please set the context to cluster3 by running:

kubectl config use-context cluster3

In this task, we have to create two identical environments that are running different versions of the application. The team decided to use the Blue/green deployment method to deploy a total of 10 application pods which can mitigate common risks such as downtime and rollback capability.

Also, we have to route traffic in such a way that 30% of the traffic is sent to the green-apd environment and the rest is sent to the blue-apd environment. All the development processes will happen on cluster 3 because it has enough resources for scalability and utility consumption.

Specification details for creating a blue-apd deployment are listed below: -

The name of the deployment is blue-apd.
Use the label type-one: blue.
Use the image kodekloud/webapp-color:v1.
Add labels to the pod type-one: blue and version: v1.

Specification details for creating a green-apd deployment are listed below: -

The name of the deployment is green-apd.
Use the label type-two: green.
Use the image kodekloud/webapp-color:v2.
Add labels to the pod type-two: green and version: v1.

We have to create a service called route-apd-svc for these deployments. Details are here: -

The name of the service is route-apd-svc.
Use the correct service type to access the application from outside the cluster and application should listen on port 8080.
Use the selector label version: v1.

NOTE: - We do not need to increase replicas for the deployments, and all the resources should be created in the default namespace.

You can check the status of the application from the terminal by running the curl command with the following syntax:

curl http://cluster3-controlplane:NODE-PORT

You can SSH into the cluster3 using ssh cluster3-controlplane command.

Solution
Run the following command to change the context: -

kubectl config use-context cluster3

In this task, we will use the kubectl command. Here are the steps: -

Use the kubectl create command to create a deployment manifest file as follows: -

kubectl create deployment blue-apd --image=kodekloud/webapp-color:v1 --dry-run=client -o yaml > <FILE-NAME-1>.yaml

Do the same for the other deployment and service.

kubectl create deployment green-apd --image=kodekloud/webapp-color:v2 --dry-run=client -o yaml > <FILE-NAME-2>.yaml

kubectl create service nodeport route-apd-svc --tcp=8080:8080 --dry-run=client -oyaml > <FILE-NAME-3>.yaml

Open the file with any text editor such as vi or nano and make the changes as per given in the specifications. It should look like this: -

---

apiVersion: apps/v1
kind: Deployment
metadata:
labels:
type-one: blue
name: blue-apd
spec:
replicas: 7
selector:
matchLabels:
type-one: blue
version: v1
template:
metadata:
labels:
version: v1
type-one: blue
spec:
containers: - image: kodekloud/webapp-color:v1
name: blue-apd

We will deploy a total of 10 application pods. Also, we have to route 70% traffic to blue-apd and 30% traffic to the green-apd deployment according to the task description.

Since the service distributes traffic to all pods equally, we have to set the replica count 7 to the blue-apd deployment so that the given service will send ~70% traffic to the deployment pods.

green-apd deployment should look like this: -

---

apiVersion: apps/v1
kind: Deployment
metadata:
labels:
type-two: green
name: green-apd
spec:
replicas: 3
selector:
matchLabels:
type-two: green
version: v1
template:
metadata:
labels:
type-two: green
version: v1
spec:
containers: - image: kodekloud/webapp-color:v2
name: green-apd

route-apd-svc service should look like this: -

---

apiVersion: v1
kind: Service
metadata:
labels:
app: route-apd-svc
name: route-apd-svc
spec:
type: NodePort
ports: - port: 8080
protocol: TCP
targetPort: 8080
selector:
version: v1

Now, create a deployment and service by using the kubectl create -f command: -

kubectl create -f <FILE-NAME-1>.yaml -f <FILE-NAME-2>.yaml -f <FILE-NAME-3>.yaml

#### q10

Task
SECTION: SERVICES AND NETWORKING
For this question, please set the context to cluster3 by running:

kubectl config use-context cluster3

We have an external webserver running on student-node which is exposed at port 9999.

We have also created a service called external-webserver-ckad01-svcn that can connect to our local webserver from within the cluster3 but, at the moment, it is not working as expected.

Fix the issue so that other pods within cluster3 can use external-webserver-ckad01-svcn service to access the webserver.

Solution
Let's check if the webserver is working or not:

student-node ~ ➜ curl student-node:9999
...

<h1>Welcome to nginx!</h1>
...

Now we will check if service is correctly defined:

student-node ~ ➜ kubectl describe svc external-webserver-ckad01-svcn
Name: external-webserver-ckad01-svcn
Namespace: default
.
.
Endpoints: <none> # there are no endpoints for the service
...

As we can see there is no endpoints specified for the service, hence we won't be able to get any output. Since we can not destroy any k8s object, let's create the endpoint manually for this service as shown below:

student-node ~ ➜ export IP_ADDR=$(ifconfig eth0 | grep 'inet ' | awk '{print $2}')

student-node ~ ➜ kubectl apply -f - <<EOF
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
name: external-webserver-ckad01-svcn
labels:
kubernetes.io/service-name: external-webserver-ckad01-svcn
addressType: IPv4
ports:

- protocol: TCP
  port: 9999
  endpoints:
- addresses: - $IP_ADDR
  EOF

Finally check if the curl test works now:

student-node ~ ➜ kubectl --context cluster3 run --rm -i test-curl-pod --image=curlimages/curl --restart=Never -- curl -m 2 external-webserver-ckad01-svcn
...

<title>Welcome to nginx!</title>
...

Details

### Q 12

SECTION: SERVICES AND NETWORKING

For this question, please set the context to cluster1 by running:

kubectl config use-context cluster1

For this scenario, create a Service called ckad12-service that routes traffic to an external IP address.

Please note that service should listen on port 53 and be of type ExternalName. Use the external IP address 8.8.8.8

Create the service in the default namespace.

Solution
Create the service using the following manifest:

apiVersion: v1
kind: Service
metadata:
name: ckad12-service
spec:
type: ExternalName
externalName: 8.8.8.8
ports: - name: http
port: 53
targetPort: 53

####

Q14

For this question, please set the context to cluster2 by running:

kubectl config use-context cluster2

Create a custom resource my-anime of kind Anime with the below specifications:

Name of Anime: Death Note
Episode Count: 37

TIP: You may find the respective CRD with anime substring in it.

Solution
student-node ~ ➜ kubectl config use-context cluster2
Switched to context "cluster2".

student-node ~ ➜ kubectl get crd | grep -i anime
animes.animes.k8s.io

student-node ~ ➜ kubectl get crd animes.animes.k8s.io \
 -o json \
 | jq .spec.versions[].schema.openAPIV3Schema.properties.spec.properties
{
"animeName": {
"type": "string"
},
"episodeCount": {
"maximum": 52,
"minimum": 24,
"type": "integer"
}
}

student-node ~ ➜ k api-resources | grep anime
animes an animes.k8s.io/v1alpha1 true Anime

student-node ~ ➜ cat << YAML | kubectl apply -f -
apiVersion: animes.k8s.io/v1alpha1
kind: Anime
metadata:
name: my-anime
spec:
animeName: "Death Note"
episodeCount: 37
YAML
anime.animes.k8s.io/my-anime created

student-node ~ ➜ k get an my-anime
NAME AGE
my-anime 23s

### q15

For this question, please set the context to cluster1 by running:

kubectl config use-context cluster1

Create a ConfigMap named ckad04-config-multi-env-files-aecs in the default namespace from the environment(env) files provided at /root/ckad04-multi-cm directory.

Solution
student-node ~ ➜ kubectl config use-context cluster1
Switched to context "cluster1".

student-node ~ ➜ kubectl create configmap ckad04-config-multi-env-files-aecs \
 --from-env-file=/root/ckad04-multi-cm/file1.properties \
 --from-env-file=/root/ckad04-multi-cm/file2.properties
configmap/ckad04-config-multi-env-files-aecs created

student-node ~ ➜ k get cm ckad04-config-multi-env-files-aecs -o yaml
apiVersion: v1
data:
allowed: "true"
difficulty: fairlyEasy
exam: ckad
modetype: openbook
practice: must
retries: "2"
kind: ConfigMap
metadata:
name: ckad04-config-multi-env-files-aecs
namespace: default

### q16

Task
SECTION: APPLICATION ENVIRONMENT, CONFIGURATION and SECURITY

For this question, please set the context to cluster2 by running:

kubectl config use-context cluster2

Create a ResourceQuota called ckad16-rqc in the namespace ckad16-rqc-ns and enforce a limit of one ResourceQuota for the namespace.

Solution
student-node ~ ➜ kubectl config use-context cluster2
Switched to context "cluster2".

student-node ~ ➜ kubectl create namespace ckad16-rqc-ns
namespace/ckad16-rqc-ns created

student-node ~ ➜ cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
name: ckad16-rqc
namespace: ckad16-rqc-ns
spec:
hard:
resourcequotas: "1"
EOF

resourcequota/ckad16-rqc created

student-node ~ ➜ k get resourcequotas -n ckad16-rqc-ns
NAME AGE REQUEST LIMIT
ckad16-rqc 20s resourcequotas: 1/1

### Q18

Task
SECTION: APPLICATION ENVIRONMENT, CONFIGURATION and SECURITY

For this question, please set the context to cluster2 by running:

kubectl config use-context cluster2

Using the pod template on student-node at /root/ckad08-dotfile-aecs.yaml , create a pod ckad18-secret-pod in the namespace ckad18-secret with the specifications as defined below:

Define a volume section named secret-volume that is backed by a Kubernetes Secret named ckad18-secret-aecs.

Mount the secret-volume volume to the container's /etc/secret-volume directory in read-only mode, so that the container can access the secrets stored in the ckad18-secret-aecs secret.

Solution
cat << 'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
name: ckad18-secret-pod
namespace: ckad18-secret
spec:
restartPolicy: Never
volumes:

- name: secret-volume
  secret:
  secretName: ckad18-secret-aecs
  containers:
- name: ckad08-top-scrt-ctr-aecs
  image: registry.k8s.io/busybox
  command: - ls - "-al" - "/etc/secret-volume"
  volumeMounts: - name: secret-volume
  readOnly: true
  mountPath: "/etc/secret-volume"
  EOF

#### q19

Task
SECTION: APPLICATION OBSERVABILITY AND MAINTENANCE

For this question, please set the context to cluster1 by running:

kubectl config use-context cluster1

Update the newly created pod simple-webapp-aom with a readinessProbe using the given specifications.

Configure an HTTP readiness probe with:

path value set to /ready

port number to access container is 8080

initialDelaySeconds set to 15 (to allow app startup time)

Note: You need to recreate the pod to add the readiness probe configuration.

###Q20

For this question, please set the context to cluster1 by running:

kubectl config use-context cluster1

Pod manifest file is already given under the /root/ directory called ckad-pod-busybox.yaml.

There is error with manifest file correct the file and create resource.

Solution
You will see following error

student-node ~ ➜ kubectl create -f ckad-pod-busybox.yaml
Error from server (BadRequest): error when creating "ckad-pod-busybox.yaml": Pod in version "v1" cannot be handled as a Pod.

Use the following yaml file and create resource

apiVersion: v1
kind: Pod
metadata:
name: ckad-pod-busybox
spec:
containers: - command: - sleep - "3600"
image: busybox
name: pods-simple-container

### Q21

For this question, please set the context to cluster3 by running:

kubectl config use-context cluster3

Create a new pod with image redis and name ckad-probe and configure the pod with livenessProbe with command ls and set initialDelaySeconds to 5 .

TIP: - Make use of the imperative command to create the above pod.

Solution
Using imperative command

kubectl run ckad-probe --image=redis --dry-run=client -o yaml > ckad-probe.yaml

Use the following YAML file update yaml with livenessProbe

apiVersion: v1
kind: Pod
metadata:
creationTimestamp: null
labels:
run: redis
name: ckad-probe
spec:
containers: - image: redis
imagePullPolicy: IfNotPresent
name: redis
resources: {}
livenessProbe:
exec:
command: - ls
initialDelaySeconds: 5
dnsPolicy: ClusterFirst
restartPolicy: Never
status: {}

To recreate the pod, run the command:

kubectl create -f ckad-probe.yaml
