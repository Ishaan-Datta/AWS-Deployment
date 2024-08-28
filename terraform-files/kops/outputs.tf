output "bastion_public_ips" {
  value = data.aws_instance.bastion.*.public_ip
}