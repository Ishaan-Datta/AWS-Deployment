output "s3_bucket" {
  value = aws_s3_bucket.kops_bucket.id
}

output "az" {
  value = data.aws_availability_zones.available.names[0]
}

// We're storing the cluster name in our Terraform state so that
// we don't have to use our shell's environment to remember it.
output "cluster_name" {
  value = "kops-cluster-${random_string.random.result}.k8s.local"
}

output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

# ALB
# output "elb_dns_name" {
#   value = var.use_ingress_controller ? "" : aws_elb.frontend_elb.dns_name
# }

# kubeconfig

output "kops_state_store" {
  value = aws_s3_bucket.kops_state_store.bucket
}