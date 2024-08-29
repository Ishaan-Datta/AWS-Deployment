terraform {
  required_providers {
    aws        = {
      source   = "hashicorp/aws"
      version  = "5.64.0"
    }
  }
}

resource "aws_iam_role" "kops_role" {
  name                = "kops-role"
  assume_role_policy  = jsonencode({
    Version           = "2012-10-17",
    Statement         = [{
      Action          = "sts:AssumeRole",
      Effect          = "Allow",
      Principal       = {
        Service       = "ec2.amazonaws.com"
      }
    }]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
  ]
  tags                = merge(var.tags, {
    Name              = "kops-role"
  })
}

resource "null_resource" "kops_cluster" {
  provisioner "local-exec" {
    command = <<EOT
      set -e
      KOPS_CMD="kops create cluster \
        --name=${var.cluster_name} \
        --state=${var.state_store} \
        --zones=${join(",",var.availability_zones)} \
        --vpc=${var.vpc_id} \
        --subnets=${join(",", var.private_subnet_ids)} \
        --utility-subnets=${join(",", var.public_subnet_ids)} \
        --topology=private \
        --node-count=1 \
        --node-size=t3.small \ 
        --master-size=t3.medium" \
        --kubeconfig=${pathexpand(var.kubeconfig_path)}

      if [ "${var.enable_bastion}" = "true" ]; then
        KOPS_CMD="$KOPS_CMD --bastion --ssh-public-key=${pathexpand(var.ssh_key_path)}"
      fi

      eval $KOPS_CMD

      kops update cluster --name=${var.cluster_name} --yes --state=${var.state_store} --admin
      kops validate cluster --name=${var.cluster_name} --state=${var.state_store} --wait 10m
      kops export kubecfg --admin --name=${var.cluster_name} --state=${var.state_store}
    EOT
  }
}

data "aws_instance" "bastion" {
  filter {
    name      = "tag:Name"
    values    = ["${var.cluster_name}-bastion*"]
  }
  filter {
    name      = "instance-state-name"
    values    = ["running"]
  }
  depends_on  = [ null_resource.kops_cluster ]
}