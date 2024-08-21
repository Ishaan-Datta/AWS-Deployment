# Kubernetes Cluster Local Testing Guide with Minikube

This guide will help you set up a local Kubernetes cluster using Minikube, install Helm, and test your deployments with strict frontend access or through an Ingress.

## Prerequisites

Before starting, ensure you have the following installed:

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Helm](https://helm.sh/docs/intro/install/)

## Step 1: Install `kubectl`

Follow the official [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for your operating system.

Verify the installation:

```bash
kubectl version --client
```

## Step 2: Install Minikube

Follow the official Minikube installation guide for your operating system.

Start a Minikube cluster:
```bash
minikube start
```

Verify that Minikube is running:
```bash
minikube status
```

## Step 3: Install Helm
Follow the official Helm installation guide for your operating system.

Verify the installation:
```bash
helm version
```

## Step 4: Install the helm chart
1. Navigate to the Deployment Directory:
    ```bash
    cd deployment/AWS-deployment
    ```
2. Install the Helm Chart:
    ```bash
    helm install myapp ./mychart --set deployment.localTesting=true --set deployment.ingressEnabled=false
    ```
3. Follow the notes instructions page for more information

## Cleaning up:
minikube addons enable ingress
kubectl get pods -n ingress-nginx
helm install myapp ./mychart --set deployment.localTesting=true --set deployment.ingressEnabled=true

helm uninstall my-release
minikube stop