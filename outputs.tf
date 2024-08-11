output "eks_cluster_name" {
  value = module.eks.cluster_id
}

output "rds_endpoint" {
  value = aws_db_instance.default.endpoint
}
