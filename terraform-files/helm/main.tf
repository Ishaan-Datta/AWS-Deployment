terraform {
  required_providers {
    kubernetes = {
      source   = "hashicorp/kubernetes"
      version  = "2.32.0"
    }
    helm       = {
      source   = "hashicorp/helm"
      version  = "2.15.0"
    }
  }
}

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

resource "null_resource" "sleep_for_ingress" {
  provisioner "local-exec" {
    command  = "sleep 30"
  }
  depends_on = [kubernetes_namespace.my_namespace]
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
  depends_on = [null_resource.sleep_for_ingress]
}

data "kubernetes_service" "ingress-nginx" {
  count       = var.use_ingress_controller ? 1 : 0
  metadata {
    name      = "ingress-nginx-controller"
    namespace = helm_release.nginx_ingress[0].metadata[0].namespace
  }
}

data "kubernetes_service" "web" {
  count       = var.use_ingress_controller ? 0 : 1
  metadata {
    name      = var.deployment_name
    namespace = helm_release.helm_deployment.metadata[0].namespace
  }
}