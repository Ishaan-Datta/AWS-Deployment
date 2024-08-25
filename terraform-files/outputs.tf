output "cluster_name" {
  value = local.kops_cluster_name
}

output "kops_state_store_name" {
  value = local.kops_state_store_name
}

output "kops_state_store_bucket" {
  value = local.kops_state_store_id
}

output "availability_zones" {
  value = local.azs
}

output "environment" {
  value = var.environment_name
}

output "namespace" {
  value = var.namespace
}

output "s3_bucket_id" {
  value = module.s3.bucket_id
}

output "network_public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "network_private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "network_vpc_id" {
  value = module.network.vpc_id
}