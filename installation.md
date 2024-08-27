# Kubernetes Cluster Local Testing Guide with Minikube

This guide will help set up a local Kubernetes cluster using Minikube, install Helm, and test the deployments with strict frontend access or through an Ingress.

## Step 1: Install `kubectl`

Follow the official [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for your operating system.

Verify the installation:

```bash
kubectl version --client
```

## Step 2: Install `Minikube`

Follow the official [Minikube installation guide](https://minikube.sigs.k8s.io/docs/start/) for your operating system.

Start a Minikube cluster:
```bash
minikube start
```

Verify that Minikube is running:
```bash
minikube status
```

## Step 3: Install `Helm`
Follow the official [Helm installation guide](https://helm.sh/docs/intro/install/) for your operating system.

Verify the installation:
```bash
helm version
```

## Step 4: Install the helm chart
1. Navigate to the Deployment Directory:
```bash
cd helm-chart
```
2. Enable the Ingress Controller (if you plan on using the ingress feature):
```bash
minikube addons enable ingress
```
3. Install the Helm Chart: (you can change the ingressEnabled value to true to test the ingress)
```bash
helm install test AWS-Deployment --set deployment.localTesting=true --set deployment.ingressEnabled=false
```
4. Follow the helm chart instructions output for more steps

## Step 5. Cleaning up:
1. Uninstall the helm release:
```bash
helm uninstall my-release
```
2. Stop Minikube:
```bash
minikube stop
```