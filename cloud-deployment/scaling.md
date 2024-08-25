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


    Use the kOps Terraform module to generate the necessary security groups and deploy the Kubernetes cluster on the nodes.

Configure kOps to use the existing network infrastructure: You can configure kOps to use the existing VPC, subnets, and other networking resources created by Terraform by specifying them in your cluster's configuration.

Apply the kOps Terraform configuration: Finally, apply the kOps Terraform configuration using terraform apply. This will create the Kubernetes cluster, security groups, and other kOps-managed resources within the infrastructure you provisioned.

This configuration ensures that the pod is only scheduled on nodes labeled as being in a private subnet.

NAT Gateway per Subnet:
You don't need a NAT gateway for each subnet, but it's a common practice to have one NAT gateway per Availability Zone (AZ) for high availability and redundancy. If you only have one NAT gateway in one AZ and that AZ fails, instances in other AZs won't have internet access if they rely on that NAT gateway. So, if your VPC spans multiple AZs, it's recommended to have a NAT gateway in each AZ to avoid a single point of failure.

Definition: In a Kops cluster, utility subnets are public subnets that host shared resources required by the cluster, such as load balancers, NAT gateways, and bastion hosts.
Purpose: Utility subnets are where Kops places resources that need public IPs or internet access. For example, if you have a LoadBalancer service in Kubernetes, the associated AWS load balancer will be placed in a utility subnet.

Bastion Hosts: If you need to SSH into instances in private subnets, you might use a bastion host placed in a utility subnet to securely jump into private instances.

Public Subnets (Utility Subnets): Used for placing resources that need internet access or are publicly accessible, such as NAT gateways and load balancers.
Private Subnets: Where your application's backend services and databases are placed, ensuring they are not directly exposed to the internet. They use the NAT gateway in the utility subnet for outbound internet access.

Kops will automatically map the master nodes to the private subnets and the utility (public) subnets to AWS resources like load balancers or NAT gateways.
The worker nodes will also be placed in the private subnets by default, with access to the internet via the NAT gateway in the public subnet.

Worker Nodes in Availability Zones: When you create a Kubernetes cluster using Kops, and specify subnets (both public and private) across multiple Availability Zones (AZs), Kops ensures that worker nodes are placed into the private subnets that correspond to the specific AZ they are part of.

    Example: If you have a private subnet in us-east-1a, a worker node that is designated for us-east-1a will be placed in the private subnet within that AZ, not in a private subnet of another AZ like us-east-1b.

SSH Access Process:

    First, SSH into the bastion host using its public IP.
    Then, from the bastion host, SSH into any of the master nodes using their private IPs within the VPC.

kops places bastion host in public subnet for each az

Kops will automatically configure security groups to allow SSH from the bastion host to the master nodes in the private subnets. The bastion host’s security group will permit SSH access from your local machine's IP range.

utilize horizontal scaling, - adding more instances (nodes) to distribute the load across multiple machines.
- **Use Case**: Ideal for stateless applications that can run on multiple nodes. It enhances fault tolerance, as even if one node fails, others can handle the load.
- **Advantages**: More resilient and scalable than vertical scaling.

Public vs. Private Subnets:

    Public Subnet: This is a subnet that has a route to the internet, typically via an Internet Gateway (IGW). Resources in this subnet can be directly accessed from outside the VPC.
    Private Subnet: This is a subnet without direct access to the internet. Resources in private subnets typically communicate with the outside world through a NAT Gateway or NAT instance, if needed.

Use Case:

    Load Balancer in Public Subnet: You want the load balancer to be accessible from the internet so that it can route external traffic to your services.
    Worker Nodes in Private Subnet: You want the worker nodes, which run your application pods, to be in private subnets to keep them secure and not directly exposed to the internet.

Create Public and Private Subnets:

    Ensure you have both public and private subnets defined in your VPC. Public subnets should have a route to an Internet Gateway, while private subnets should route outbound traffic through a NAT Gateway or NAT instance.

Configure Security Groups:

    Load Balancer Security Group: This should allow inbound traffic from the internet (e.g., HTTP/HTTPS ports) and outbound traffic to the private subnet.
    Worker Node Security Group: This should allow inbound traffic from the load balancer (typically on the ports your services are exposed on) and outbound traffic to the internet if necessary (e.g., for pulling container images).

Private Subnets (Backend Services): Backend services, databases, and other internal services should run on worker nodes in private subnets to ensure they are not exposed to the public internet.
Public Subnets (Load Balancers): Load balancers and services that need to be accessible from the public internet are typically configured in public subnets. While the load balancer itself is in a public subnet, the worker nodes running the actual application pods can still be in private subnets.

Rolling Updates: When a new version of an application is deployed, Kubernetes will gradually replace the old Pods with new ones. This ensures minimal disruption and maintains application availability during the update process.

using EC2 T3 instances for micro-services, low-latency interactive applications, small and medium databases, virtual desktops, development environments, code repositories, and business-critical applications

waits 10 minutes