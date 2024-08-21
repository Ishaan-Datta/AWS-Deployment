Nodes in the Cluster: The cluster is initially set to run 2 nodes, with the ability to scale between 1 and 3 nodes depending on the workload.

kubectl scale deployment my-nginx --replicas=0; kubectl scale deployment my-nginx --replicas=2;
kubectl get pods -l run=my-nginx -o wide
Kubernetes offers a DNS cluster addon Service that automatically assigns dns names to other Services. You can check if it's running on your cluster:
kubectl get services kube-dns --namespace=kube-system

cli comes into play to abstract the kubectl commands and allow scaling easily
researching how to distribute for multi cluster routing 
possibly ansible for ec2 configuration like helm commands installing

kubectl scaling deployment:
kubectl get rs
kubectl scale deployments/kubernetes-bootcamp --replicas=4
kubectl describe deployments/kubernetes-bootcamp
minikube service kubernetes-bootcamp --url

kubectl set image deployments/kubernetes-bootcamp kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2

The command notified the Deployment to use a different image for your app and initiated a rolling update. Check the status of the new Pods, and view the old one terminating with the get pods subcommand:
kubectl rollout status deployments/kubernetes-bootcamp
kubectl rollout undo deployments/kubernetes-bootcamp

Once you've created a Service of type LoadBalancer, you can use this command to find the external IP:
kubectl get service frontend --watch
curl http://${EXTERNAL_IP} # replace this with the EXTERNAL-IP you saw earlier

clusters should be region specific 
horizontal vs vertical scaling etc.

containers can make use of kubectl api to determine what pod they are in?
otherwise pipe directly into the frontend service

kubectl get replicasets
kubectl describe replicasets
kubectl cluster-info