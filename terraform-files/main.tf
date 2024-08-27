data "aws_regions" "available" {}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_string" "random" {
  length  = 16
  lower   = true
  upper   = false
  special = false
  numeric = false
}

locals { 
  azs                         = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  kops_cluster_name           = "kops-cluster-${random_string.random.result}.k8s.local"
  kops_state_store_name       = "${random_string.random.result}-kops-bucket"
  kops_state_store_id         = "s3://${random_string.random.result}-kops-bucket"
  public_subnet_cidr_blocks   = [for i in range(var.az_count) : cidrsubnet("10.0.0.0/16", 8, i)]
  private_subnet_cidr_blocks  = [for i in range(var.az_count) : cidrsubnet("10.0.0.0/16", 8, i + var.az_count)]
  helm_chart_path             = pathexpand("./helm-chart/AWS-Deployment")
  az_count                    = length(local.azs)
  tags                        = {
    terraform                 = true
    environment               = "${var.environment_name}"
  }
}

module "network" {
  source                     = "./network"
  providers                  = {
    aws                      = aws.aws-region-provider
  }
  vpc_cidr                   = "10.0.0.0/16"
  az_count                   = local.az_count
  public_subnet_cidr_blocks  = local.public_subnet_cidr_blocks
  private_subnet_cidr_blocks = local.private_subnet_cidr_blocks
  azs                        = data.aws_availability_zones.available.names
  tags                       = local.tags
  vpc_name                   = var.vpc_name
  kops_cluster_name          = local.kops_cluster_name
}

module "s3" {
  source      = "./s3"
  providers   = {
    aws       = aws.aws-region-provider
  }
  bucket_name = local.kops_state_store_name
  tags        = local.tags
  depends_on  = [ module.network ]
}

module "kops" {
  source             = "./kops"
  providers          = {
    aws              = aws.aws-region-provider
  }
  cluster_name       = local.kops_cluster_name
  state_store        = local.kops_state_store_id
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  public_subnet_ids  = module.network.public_subnet_ids
  ssh_key_path       = var.ssh_key_path
  availability_zones = data.aws_availability_zones.available.names
  enable_bastion     = var.enable_bastion
  tags               = local.tags
  depends_on         = [ module.s3 ]
}

module "helm" {
  source                 = "./helm"
  providers              = {
    kubernetes           = kubernetes
    helm                 = helm
  }
  use_ingress_controller = var.use_ingress_controller
  namespace              = var.namespace
  deployment_name        = var.deployment_name
  az_count               = local.az_count
  aws_region             = var.aws_region
  helm_chart_path        = local.helm_chart_path
  depends_on             = [module.kops]
}