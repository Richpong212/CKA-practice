```
### Task 5
SECTION: APPLICATION DESIGN AND BUILD


For this question, please set the context to cluster1 by running:


kubectl config use-context cluster1



In the ckad-pod-design namespace, we created a pod named custom-nginx that runs the nginx:1.17 image.

Take appropriate actions to update the index.html page of this NGINX container with below value instead of default NGINX welcome page:


Welcome to CKAD mock exams!



NOTE: By default NGINX web server default location is at /usr/share/nginx/html which is located on the default file system of the Linux.

Solution
Exec to the pod container and update the index.html file content:


student-node ~ ➜kubectl exec -it -n ckad-pod-design custom-nginx -- sh
# echo 'Welcome to CKAD mock exams!' > /usr/share/nginx/html/index.html



Observe the result:


student-node ~ ➜  kubectl exec -it -n ckad-pod-design custom-nginx -- cat /usr/share/nginx/html/index.html
Welcome to CKAD mock exams!


### Task 9
SECTION: SERVICES AND NETWORKING


For this question, please set the context to cluster3 by running:


kubectl config use-context cluster3



We have deployed several applications in the ns-ckad17-svcn namespace that are exposed inside the cluster via ClusterIP.


Your task is to create a LoadBalancer type service that will serve traffic to the applications based on its labels. Create the resources as follows:

Service lb1-ckad17-svcn for serving traffic at port 31890 to pods with labels "exam=ckad, criteria=location".

Service lb2-ckad17-svcn for serving traffic at port 31891 to pods with labels "exam=ckad, criteria=cpu-high".
Solution
To create the loadbalancer for the pods with the specified lables, first we need to find the pods with the mentioned lables.

To get pods with labels "exam=ckad, criteria=location"
kubectl -n ns-ckad17-svcn get pod -l exam=ckad,criteria=location
-----
NAME               READY   STATUS    RESTARTS   AGE
geo-location-app   1/1     Running   0          10m

Similarly to get pods with labels "exam=ckad,criteria=cpu-high".
kubectl -n ns-ckad17-svcn get pod -l exam=ckad,criteria=cpu-high
-----
NAME           READY   STATUS    RESTARTS   AGE
cpu-load-app   1/1     Running   0          11m

Now we know which pods use the labels, we can create the LoadBalancer type service using the imperative command.

kubectl -n ns-ckad17-svcn expose pod geo-location-app --type=LoadBalancer --name=lb1-ckad17-svcn

Similarly, create the another service.

kubectl -n ns-ckad17-svcn expose pod cpu-load-app --type=LoadBalancer --name=lb2-ckad17-svcn



Once the services are created, you can edit the services to use the correct nodePorts as per the question using kubectl -n ns-ckad17-svcn edit svc lb2-ckad17-svcn.


### Task 10
SECTION: SERVICES AND NETWORKING


For this question, please set the context to cluster3 by running:


kubectl config use-context cluster3



We have created a Network Policy netpol-ckad13-svcn that allows traffic only to specific pods and it allows traffic only from pods with specific labels.

Your task is to edit the policy so that it allows traffic from pods with labels access = allowed.



Do not change the existing rules in the policy.

Solution
To edit the existing network policy use the following command:

kubectl edit netpol netpol-ckad13-svcn



Edit the policy as follows:

apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: netpol-ckad13-svcn
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: kk-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
           tier: server
#add the following in the manifest
    - podSelector:
        matchLabels:
           access: allowed



## 14 Task
SECTION: APPLICATION ENVIRONMENT, CONFIGURATION and SECURITY
For this question, please set the context to cluster3 by running:

kubectl config use-context cluster3

In the ckad14-sa-projected namespace, configure the ckad14-api-pod Pod to include a projected volume named vault-token.

Mount the service account token to the container at /var/run/secrets/tokens, with an expiration time of 7000 seconds.

Additionally, set the intended audience for the token to vault and path to vault-token.

Solution
student-node ~ ➜  kubectl config use-context cluster3
Switched to context "cluster3".

student-node ~ ➜  k get pod -n ckad14-sa-projected ckad14-api-pod -o yaml > ckad-pro-vol.yaml

student-node ~ ➜  cat ckad-pro-vol.yaml
apiVersion: v1
kind: Pod
metadata:
  name: ckad14-api-pod
  namespace: ckad14-sa-projected
spec:
  containers:
  - image: nginx
    imagePullPolicy: Always
    name: nginx
.
.
.
   volumeMounts:                              # Added
    - mountPath: /var/run/secrets/tokens       # Added
      name: vault-token                        # Added
.
.
.
  serviceAccount: ckad14-sa
  serviceAccountName: ckad14-sa
  volumes:
  - name: vault-token                   # Added
    projected:                          # Added
      sources:                          # Added
      - serviceAccountToken:            # Added
          path: vault-token             # Added
          expirationSeconds: 7000       # Added
          audience: vault               # Added

student-node ~ ➜  k replace -f ckad-pro-vol.yaml --force
pod "ckad14-api-pod" deleted
pod/ckad14-api-pod replaced

### Task 15
For this question, please set the context to cluster3 by running:


kubectl config use-context cluster3



Create a custom resource my-anime of kind Anime with the below specifications:


Name of Anime: Naruto
Episode Count: 220


TIP: You may find the respective CRD with anime substring in it.

Solution
student-node ~ ➜  kubectl config use-context cluster3
Switched to context "cluster3".

student-node ~ ➜  kubectl get crd | grep -i anime
animes.animes.k8s.io

student-node ~ ➜  kubectl get crd animes.animes.k8s.io \
                 -o json \
                 | jq .spec.versions[].schema.openAPIV3Schema.properties.spec.properties
{
  "animeName": {
    "type": "string"
  },
  "episodeCount": {
    "maximum": 300,
    "minimum": 24,
    "type": "integer"
  }
}

student-node ~ ➜  k api-resources | grep anime
animes                            an           animes.k8s.io/v1alpha1                 true         Anime

student-node ~ ➜  cat << YAML | kubectl apply -f -
 apiVersion: animes.k8s.io/v1alpha1
 kind: Anime
 metadata:
   name: my-anime
 spec:
   animeName: "Naruto"
   episodeCount: 220
YAML
anime.animes.k8s.io/my-anime created

student-node ~ ➜  k get an my-anime
NAME       AGE
my-anime   23s
```
