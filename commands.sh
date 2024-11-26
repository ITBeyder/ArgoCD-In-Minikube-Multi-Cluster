docker network create -d macvlan \
--subnet=192.168.1.0/24 --gateway=192.168.1.1 \
--subnet=192.168.2.0/24 --gateway=192.168.2.1 \
--subnet=192.168.3.0/24 --gateway=192.168.3.1 \
--subnet=192.168.4.0/24 --gateway=192.168.4.1 \
-o parent=eth0 minikibe-multicluster

minikube start --addons=ingress --profile argo --network minikibe-multicluster --subnet 192.168.1.0/24 --memory=2048 --cpus=2
minikube start --addons=ingress --profile dev  --network minikibe-multicluster --subnet 192.168.2.0/24 --memory=2048 --cpus=2
minikube start --addons=ingress --profile test --network minikibe-multicluster --subnet 192.168.3.0/24 --memory=2048 --cpus=2
minikube start --addons=ingress --profile prod --network minikibe-multicluster --subnet 192.168.4.0/24 --memory=2048 --cpus=2

kubectl config use-context argo
minikube -p argo tunnel
kubectl create ns argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.5.8/manifests/install.yaml
kubectl apply -f ./ArgoCD/ingress.yaml
kubectl edit svc/kubernetes

kubectl config use-context dev
kubectl edit svc/kubernetes

kubectl config use-context test
kubectl edit svc/kubernetes

kubectl config use-context prod
kubectl edit svc/kubernetes

docker ps -a
docker exec -it xxx bash
cat /etc/kubernetes/admin.conf

kubectl create deployment temp --image=alpine:3.18 -- /bin/sh -c "tail -f /dev/null"
kubectl exec -it deploy/temp -- sh
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/
curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
chmod +x argocd
mv argocd /usr/local/bin/
mkdir -p ~/.kube
vi ~/.kube/config
vi /etc/hosts
<argo-node-ip> argocd.minikube.local
argocd login 10.101.12.243:443 <service ip and port>
kubectl config get-contexts
argocd cluster add

