output "bastion_public_ips" {
  value = var.enable_bastion ? data.aws_instance.bastion.*.public_ip : []
}