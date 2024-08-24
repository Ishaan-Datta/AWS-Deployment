Nodes in the Cluster: The cluster is initially set to run 2 nodes, with the ability to scale between 1 and 3 nodes depending on the workload.

horizontal vs vertical scaling etc.

kubectl get replicasets
kubectl describe replicasets
kubectl cluster-info

Gossip DNS uses a peer-to-peer protocol to propagate DNS information among cluster nodes. It's ideal for scenarios where you want to avoid managing an external DNS zone, such as Route 53, and is especially useful in development or testing environments. When you use private subnets with your kOps cluster, the gossip DNS system continues to function as it operates internally within the cluster. The nodes in the private subnets will be able to resolve each other’s names via the gossip DNS protocol without any need for internet-facing DNS services. With gossip DNS, there's no dependency on Route 53 or any other external DNS service, which simplifies the setup and reduces costs. This setup works well with private subnets because the DNS resolution is entirely internal to the cluster and doesn’t require any external network access.

Key Network Resources Automatically Provisioned by kOps: 
NAT Gateways: kOps can automatically create NAT Gateways for private subnets to allow outbound internet access (for pulling Docker images, updates, etc.) without exposing the instances to incoming internet traffic.
Internet Gateway (IGW): An IGW is automatically provisioned for public subnets to allow direct internet access for resources like load balancers.
Routing Tables: kOps configures the appropriate routing tables to ensure that public subnets route traffic to the IGW and private subnets route traffic through the NAT Gateway.
Security Groups: kOps also automatically sets up security groups with rules to control the traffic between the components of the cluster and external sources.
ingress for single point routing
Use Terraform to Provision Network Infrastructure:
You can use Terraform to define and create all the necessary network components such as VPC, subnets (public and private), internet gateways (IGW), NAT gateways, and route tables. Here's a simple example of how you might define a VPC with subnets:

you're using Terraform to orchestrate the execution of kOps commands
kOps does the heavy lifting of provisioning and managing the Kubernetes cluster infrastructure on AWS. like EC2 instances, security groups, etc.
handle the ELBs, ASGs, etc. and boostrap kubernetes
NAT gateways, IGWs, routing tables

private subnets: isolates backend microservices from public internet, adding a layer of security by only allowing access by resources within the VPC such as the loadbalancer in the public subnet. Or communicate through controlled access points like NAT gateway and IGW

private network topology
Architecture: 
front end services like the load balancer in public subnets to maintain accessiblity from the internet

backend services including database, internal APIs reside in public subnets

for backend services in private subnets to access internet for updates or external API calls, NAT gateway is used to enable outbound traffic from private subnet, but blocking inbound traffic

single point ingress for internal routing

Kubernetes will automatically provision the LoadBalancer in the public subnet because the service type is LoadBalancer, and the annotations specify a public, classic ELB.

Communication Between Frontend LoadBalancer in Public Subnet and Backend Services in Private Subnet: 
There should be no issues with your frontend LoadBalancer service being inside the public subnet and sending API requests to backend services in the private subnet. Here's why:

    Routing: As long as the networking configuration (e.g., VPC routing tables, security groups) is correctly set up to allow traffic between the public and private subnets, the frontend LoadBalancer should be able to communicate with backend services in the private subnet without issues.

    Security Groups: Ensure that the security groups associated with your backend services allow inbound traffic from the LoadBalancer or the frontend pods.

    Private Subnet Accessibility: Since the backend services are in the private subnet, they won’t be directly exposed to the internet, which is a typical setup to maintain security.

Subnets and Accessibility: The automatically provisioned LoadBalancer for the Ingress controller will be internet-facing (aws-load-balancer-internal="false"), and it will be deployed in the public subnets. This means it will expose the Ingress controller to the internet.

Routing Traffic to Private Subnet Pods:

    Ingress and Backend Pods: The Ingress controller's LoadBalancer will receive external traffic and route it to the appropriate services (which might be in private subnets). The routing will work as long as the Kubernetes network policies and security groups allow traffic from the Ingress controller to the backend pods in the private subnet.

    Networking: Ensure that the VPC, subnet routing, and security groups are correctly configured to allow traffic flow from the public subnet (where the Ingress LoadBalancer is) to the private subnet (where backend services are).