output "elb_url" {
  value = file("${path.module}/service_ip.txt")
}
