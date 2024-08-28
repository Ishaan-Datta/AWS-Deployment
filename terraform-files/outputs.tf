output "output_message" {
  value = <<EOT
"Your resources have been deployed into the ${var.environment_name} Terraform environment, ${var.namespace} Kubernetes namespace"
"They are located in the following ${local.az_count} availability zones: ${local.azs} of region: ${var.aws_region}"

Network resources:
"The VPC name is: ${var.vpc_name} and the VPC ID is: ${module.network.vpc_id}"
"The public subnet IDs are: ${module.network.public_subnet_ids}"
"The private subnet IDs are: ${module.network.private_subnet_ids}"

kOps Cluster Resources:
"The Kubernetes cluster name is: ${local.kops_cluster_name}, and the bucket is: ${local.kops_state_store_id}"

Helm Resources:
"The Helm chart release name is: ${var.deployment_name}"
%{ if var.use_ingress_controller ~}
The Ingress Controller chart release name is: nginx-ingress
%{ endif ~}

Your kubectl config has automatically been updated by kOps.

To access the cluster, you can use the following commands:

"kops get cluster --name ${local.kops_cluster_name} --state ${local.kops_state_store_id}"
"kops get ig --name ${local.kops_cluster_name} --state ${local.kops_state_store_id}"
"kops get nodes --name ${local.kops_cluster_name} --state ${local.kops_state_store_id}"

%{if var.enable_bastion ~}
The bastion hosts can be accessed at the following public IPs:
%{ for ip in module.kops.bastion_public_ips ~}
ssh -i ${var.ssh_key_path} admin@${ip}
%{ endfor ~}
%{endif ~}

To access the Kubernetes resources, you can use the following commands:

"kubectl get nodes -n ${var.namespace}"
"kubectl get pods -n ${var.namespace}"
"kubectl get services -n ${var.namespace}"
"kubectl get deployments -n ${var.namespace}"

To access the Helm resources, you can use the following commands:

"helm status ${var.deployment_name} --namespace ${var.namespace}"
"helm get all ${var.deployment_name} --namespace ${var.namespace}"

%{if var.use_ingress_controller ~}
"For accessing all services through the Ingress controller, visit the following address: ${module.helm.elb_url}"
The available endpoints are: /auth, /webapp, /recommend, /user-data
%{else ~}
"For only accessing the webapp through the Loadbalancer Service, visit the following address: ${module.helm.elb_url}"
%{endif ~}

To uninstall the resources, you can use the following commands:

"kops delete cluster --name ${local.kops_cluster_name} --state ${local.kops_state_store_id} --yes"

"After waiting a few minutes, the output should be: deleted cluster: ${local.kops_cluster_name}"

terraform destroy -auto-approve

EOT
}