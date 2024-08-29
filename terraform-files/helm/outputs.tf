output "ingress_elb_url" {
  value = data.kubernetes_service.ingress-nginx[0].status[0].load_balancer[0].ingress[0].hostname
}

output "web_elb_url" {
  value = data.kubernetes_service.web[0].status[0].load_balancer[0].ingress[0].hostname
}