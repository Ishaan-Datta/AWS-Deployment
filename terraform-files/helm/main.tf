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

resource "null_resource" "fetch_elb_urls" {
  provisioner "local-exec" {
    command = <<EOT
      NAMESPACE="${var.namespace}"
      
      # Fetch the LoadBalancer services in the specified namespace
      kubectl get services -n $NAMESPACE -o json | jq -r '
      .items[] | select(.spec.type == "LoadBalancer") | 
      "\(.metadata.name) - \(.status.loadBalancer.ingress[] | .hostname // .ip)"' > elb_urls.txt
      
      # Output the first result
      head -n 1 elb_urls.txt
    EOT
  }
  depends_on = [ null_resource.wait_for_lb ]
}