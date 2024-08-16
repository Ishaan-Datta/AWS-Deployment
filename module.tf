module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name               = "kubernetes-iac-vpc"
  cidr               = "172.17.0.0/16" # 10.0.0.0/16
  azs                = [data.aws_availability_zones.available.names[0]] # slice(data.aws_availability_zones.available.names, 1, 3)
  private_subnets    = ["172.17.1.0/24"] # ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["172.17.100.0/24"] # ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  #   // These tags are required in order for the AWS ALB ingress controller to
  #   // detect the subnets from which your targets will be pulled.
  #   // https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html
  private_subnet_tags = {
    "kubernetes.io/cluster/explore-california-cluster": "owned",
    "kubernetes.io/role/elb": "1"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/explore-california-cluster": "owned",
    "kubernetes.io/role/elb": "1"
  }
#   // The VPC needs to have access to the Internet and be able to assign DNS
#   // hostnames to EC2/adjacent instances within it for EKS workers to join your
#   // cluster (which isn't an EC2 instance set that you manage)
  enable_vpn_gateway = true
  enable_dns_support = true
  enable_dns_hostnames = true
  enable_nat_gateway = "true"
}