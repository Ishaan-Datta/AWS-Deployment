## Prerequisites

install kubectl
install kops
install awscli
login to awscli

download terraform, install, add to path
terraform init
terraform plan
visualize plan 
terraform apply
terraform show

kubectl configuring:
- install kubectl
- install AWS-cli
- Configure the AWS CLI with your credentials: aws configure
- Update `kubectl` Config:
	- Obtain the cluster endpoint and certificate authority data: aws eks update-kubeconfig --name your-cluster-name
	- Check if `kubectl` is properly configured by running: kubectl config get-contexts
- kubectl get nodes
- kubectl get pods
- kubectl get services
- kubectl logs pod-name
- kubectl logs pod-name -c container-name
- kubectl describe service frontend-service to get external DNS name

<!-- will probably need terraform to independently provision this controller... -->
installing separately:
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx/
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.service.type=LoadBalancer
helm install nginx-ingress ingress-nginx/ingress-nginx -f custom-values.yaml

Check if the NGINX Ingress Controller pods are running:
kubectl get pods -n kube-system

Check the services to find the LoadBalancer or NodePort:
kubectl get svc -n kube-system

If you're using Minikube, get the Minikube IP:
minikube ip

helm install myapp ./mychart --set deployment.local=true --set deployment.ingress=true
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx

map of configuration settings and what they change based on boolean logic

In order to use gossip-based DNS, configure the cluster domain name to end with .k8s.local

strongly recommended to use s3, otherwise will be stored in local directory
ensure you have access to the corresponding private key and file system access is permitted

terraform init
terraform init -backend-config="bucket=my-terraform-state-bucket" \
               -backend-config="key=prod/terraform.tfstate" \
               -backend-config="region=us-east-2"
terraform apply -auto-approve
Before running terraform destroy, you should manually delete the kOps cluster by running:
kops delete cluster --name your-cluster-name --state s3://your-kops-state-store --yes
after waiting a couple of minutes, last line output should be: deleted cluster: (cluster name)
terraform destroy
	- yes