resource "kubernetes_namespace" "my_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "nginx_ingress" {
  count      = var.use_ingress_controller ? 1 : 0
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx/"
  chart      = "ingress-nginx"
  namespace  = var.namespace
  set {
    name     = "controller.service.type"
    value    = "LoadBalancer"
  }
  set {
    name     = "controller.service.annotations.service.beta.kubernetes.io/aws-load-balancer-internal"
    value    = "false"
  }
  set {
    name     = "controller.service.annotations.service.beta.kubernetes.io/aws-load-balancer-type"
    value    = "classic"
  }
  depends_on = [ kubernetes_namespace.my_namespace ]
}

resource "helm_release" "helm_deployment" {
  name       = var.deployment_name
  chart      = var.helm_chart_path
  namespace  = var.namespace
  set {
    name     = "deployment.ingressEnabled"
    value    = var.use_ingress_controller
  }
  set {
    name     = "deployment.localTesting"
    value    = false
  }
  set {
    name     = "deployment.replicaCount"
    value    = var.az_count
  }
  set {
    name     = "deployment.awsRegion"
    value    = "${var.aws_region}"
  }
  depends_on = [ helm_release.nginx_ingress ]
}

resource "null_resource" "wait_for_lb" {
  provisioner "local-exec" {
    command  = "sleep 15"
  }
  depends_on = [helm_release.helm_deployment]
}

resource "null_resource" "fetch_loadbalancer_url" {
  provisioner "local-exec" {
    command = <<EOT
      if [ "${var.use_ingress_controller}" = "true" ]; then
        kubectl get services \
          --namespace ${var.namespace} \
          ingress-nginx-controller \
          --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' > service_ip.txt
      else
        kubectl get services \
          --namespace ${var.namespace} \
          web \
          --output jsonpath='{.status.loadBalancer.ingress[0].hostname}' > service_ip.txt
      fi
    EOT
  }
  depends_on = [module.kubernetes_service]
}