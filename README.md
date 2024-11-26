  

# How to setup ArgoCD In Minikube Multi Cluster
This tutorial demonstrates how to set up and manage multiple Minikube clusters and deploy applications using ArgoCD. The setup includes:
**Network Configuration:** A single Docker network using Macvlan with two subnets for Minikube clusters.
This avoids bridge network limitations and simplifies communication between clusters.
**Cluster Structure**:
* Cluster 1: Dedicated to running ArgoCD.
* Cluster 2: Hosts the deployed application.
* Management: A Docker container equipped with kubectl and argocd CLI tools to manage the clusters and deployments.
 
### Step 1: Configure the Docker Network
**A. Identify the Network Interface**
Use the ifconfig command to determine your system's active network interface

![](https://cdn-images-1.medium.com/max/2400/1*aNScrVeYiU7bQya6wDFnzw.png)

**B. Create a Macvlan Network**
*Set up a Docker network with two subnets, enabling communication between the Minikube clusters*
```
docker network create -d macvlan \

--subnet=192.168.1.0/24 -- gateway=192.168.1.1 \

-- subnet=192.168.2.0/24 -- gateway=192.168.2.1 \

--o parent=eth0 my-macvlan-network
```
### Step 2: Launch Minikube Clusters

**A. Start Minikube Clusters**
*Deploy two Minikube clusters, assigning them to the respective subnets*
```
minikube start --addons=ingress --profile argo --network my-macvlan-network --subnet 192.168.1.0/24
minikube start --addons=ingress --profile c1 --network my-macvlan-network --subnet 192.168.2.0/24
```
![](https://cdn-images-1.medium.com/max/3654/1*RKIiq_JoUc3Luj_cf8ObbA.png)

  
![](https://cdn-images-1.medium.com/max/3698/1*ytzJJnZYVDmQX_hLeof9Ag.png)

*in case you are getting this error massge , ignore it*
❗ Unable to create dedicated network, this might result in cluster IP change after restart
### Step 3: Validate Cluster Communication
A. Switch to the ArgoCD Cluster Context
```kubectl config use-context argo```
B. Deploy NGINX in the ArgoCD Cluster
*Create an NGINX deployment and expose it as a NodePort service*
```
kubectl create deployment nginx --image=nginx
kubectl expose deployment/nginx --type=NodePort --port=80
```
C. Retrieve Service Access Information
Get the Node IP and NGINX service’s NodePort:
```
kubectl get nodes -o wide
kubectl get svc
```
![](https://cdn-images-1.medium.com/max/5018/1*lnt2i216CSteocgT1mEgBg.png)

 Nginx Service → 172.17.0.2:30896

**D. Test Communication from the App Cluster (c1)**
*Switch to the app cluster context and create a temporary Alpine container to verify connectivity*
```
kubectl config use-context c1
kubectl run -it --restart=Never --image alpine tempbusybox -- sh
apk update && apk add curl
curl http://<ARGO_CLUSTER_NODE_IP>:<NGINX_NODE_PORT>
```

![](https://cdn-images-1.medium.com/max/3032/1*waD3wp9soSh9dN8pmYu9eg.png)
  
### Step 4: Deploy ArgoCD in the Argo Cluster

a. Install ArgoCD on the argo cluster
```
kubectl config use-context argo
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.5.8/manifests/install.yaml
```
![](https://cdn-images-1.medium.com/max/3456/1*6ntM4PsYjNhfrjZojFIPmw.png)
b. Retrieve the Initial Admin Password
*Extract the initial admin password for logging into the ArgoCD UI*
```kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo```
c. Create an Ingress for ArgoCD
*Create an ingress resource to expose the ArgoCD service via a domain name*
```
apiVersion: networking.k8s.io/v1

kind: Ingress

metadata:

name: argocd-ingress

namespace: argocd

annotations:

nginx.ingress.kubernetes.io/force-ssl-redirect: "true"

nginx.ingress.kubernetes.io/ssl-passthrough: "true"

nginx.ingress.kubernetes.io/rewrite-target: /

nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"

spec:

ingressClassName: nginx

rules:

- host: argocd.minikube.local

http:

paths:

- path: /

pathType: Prefix

backend:

service:

name: argocd-server

port:

number: 443
```
  
![](https://cdn-images-1.medium.com/max/3402/1*BTjJG14nWO01XnpPhLVppw.png)

d. Run the Minikube Tunnel for the argo cluster
 
```minikube tunnel```

![](https://cdn-images-1.medium.com/max/3432/1*XeJgpayAoE6zmk5nLE2_Ug.png)

*The minikube tunnel command creates a network route from your local machine to the Minikube cluster. It assigns external IPs to services with LoadBalancer type, allowing them to be accessed directly from your host. While this is not strictly necessary for ingress to work, it ensures proper routing of traffic, especially when exposing services across subnets.*
e. Update the Local Hosts File
Edit /etc/hosts to Map the ArgoCD Domain
Add an entry mapping argocd.minikube.local to 127.0.0.1 in your hosts file:

```
sudo vi /etc/hosts
127.0.0.1 argocd.minikube.local
```
*This step maps the domain argocd.minikube.local to your local machine's loopback IP, allowing you to access the ArgoCD UI using the custom domain defined in the ingress resource. Without this step, DNS resolution for the custom domain would fail.*
f. Log in to ArgoCD
*you can log in to the ArgoCD UI using “admin” username and the password you got from step ‘b’*

 ``` argocd login argocd.minikube.local```
  ![](https://cdn-images-1.medium.com/max/5352/1*Nf3L8DSugQH8cEh7xceZgw.png)
  you can also access the ArgoCD UI via your browser.
https://argocd.minikube.local
  ### Step 5: Add the App Cluster (c1) to the ArgoCD Environment
  *in this step we will expose both cluster APIs via NodePort, merge their kubeconfigs, and update with correct Node IPs and ports. Use a temporary container in c1 to install kubectl and argocd CLI, then add c1 to ArgoCD using the merged kubeconfig.*
  1. Expose Kubernetes API Services via NodePort
**For the ArgoCD cluster (argo):**
  ```
kubectl config use-context argo
kubectl edit svc/kubernetes -n default
```
  Change the type from ClusterIP to NodePort.
 
![](https://cdn-images-1.medium.com/max/2102/1*zTTPf8CCvqnL35Bqqbrhjg.png)
  2. Get the NodePort and IP
  ```
kubectl get svc kubernetes -n default
kubectl get nodes -o wide
```
  
*Note the **NodePort** and **Node IP** for accessing the API server externally.*
  ![](https://cdn-images-1.medium.com/max/7646/1*H4JFb8WyY44uxKi8LP3vOw.png)
  **For the Application cluster (c1)**
 ```
kubectl config use-context c1
kubectl edit svc/kubernetes -n default
```
  Change the type from ClusterIP to NodePort.
Get the NodePort and IP
```
kubectl get svc kubernetes -n default
kubectl get nodes -o wide
```
*Note the **NodePort** and **Node IP** for accessing the API server externally.*
  3. Export and Adjust Kubeconfig Files
*Export admin.conf for each cluster from the node (running as docker container)*
  
**For the argo cluster**
```
docker ps -a # Find the container ID for the argo Minikube cluster
docker exec -it <container_id> bash
cat /etc/kubernetes/admin.conf > /tmp/argo-config.yaml
```
  **For the c1 cluster**
  ```
docker ps -a # Find the container ID for the c1 Minikube cluster
docker exec -it <container_id> bash
cat /etc/kubernetes/admin.conf > /tmp/c1-config.yaml
```
  ![](https://cdn-images-1.medium.com/max/7628/1*vryO86ya_chMSaSXhQ5xNQ.png)

  4. Update API server endpoints
  Edit the exported files (argo-config.yaml and c1-config.yaml)
  * Replace 127.0.0.1 with the **Node IP** of the respective cluster.
* Replace the default API port (6443) with the **NodePort** obtained earlier.
  Example changes
  ```server: https://127.0.0.1:6443```
  becomes:
```server: https://<node-ip>:<node-port>```
 5. Merge Kubeconfig Files
Use a tool or merge manually as described [here](https://able8.medium.com/how-to-merge-multiple-kubeconfig-files-into-one-36fc987c2e2f). Ensure both clusters (argo and c1) are accessible in the merged kubeconfig.
  **Example:**
Original Argo KubeConfig
  ![](https://cdn-images-1.medium.com/max/2868/1*eliStFVQskEVQaDMtEDzVg.png)

  Original c1 KubeConfig
  ![](https://cdn-images-1.medium.com/max/2732/1*j8bMJ6rK4_W2qdnFL-TeSg.png)

  Combined kubeconfig file
  
  ![](https://cdn-images-1.medium.com/max/2748/1*FsId8XDMDKh8irgybkPVcw.png)

  

6. Create a Temporary Pod in c1
```
kubectl config use-context c1
kubectl create deployment temp --image=alpine:3.18 -- /bin/sh -c "tail -f /dev/null"
kubectl exec -it pod/<podname> -- /bin/sh
```
  ![](https://cdn-images-1.medium.com/max/4352/1*CoAd6wpkYaI-BtmBUt9uzQ.png)

  7. Add the merged kubeconfig file inside the container
 ```
mkdir -p ~/.kube
vi ~/.kube/config
```
  Paste the merged kubeconfig content.
 8. Add DNS entries for the ArgoCD server
```
vi /etc/hosts
<argo-node-ip> argocd.minikube.local
```

![](https://cdn-images-1.medium.com/max/2118/1*dBIhliXsPnndbdjgG4I0vQ.png)
9. Log in to ArgoCD
  ```argocd login argocd.minikube.local```
  
![](https://cdn-images-1.medium.com/max/2000/1*BT9-svlxgFQBX-J-9uJYcQ.png)
  10. Validate the contexts
```kubectl config get-contexts```
![](https://cdn-images-1.medium.com/max/2208/1*htRssrPaY49iS-1l7ThG9g.png)
11. Add c1 to ArgoCD
![](https://cdn-images-1.medium.com/max/7646/1*_k4D53eB6ZHX5thhfAMg5w.png)
validate by accessing ArgoCD UI → Settings → Clusters
![](https://cdn-images-1.medium.com/max/5978/1*GYPO-NVcYzxF4HsCQn6heg.png)
Or by cli
```argocd cluster list```

![](https://cdn-images-1.medium.com/max/2042/1*b-tRDCej72J2aY8QzIiIEg.png)
 
## Summary
This tutorial demonstrates how to set up ArgoCD for a multi-cluster Minikube environment, streamlining GitOps for Kubernetes deployments.