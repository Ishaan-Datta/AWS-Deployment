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

## Step 4: Strict frontend access
This section covers deploying your Helm chart with access limited to the frontend service.

1. Navigate to the Deployment Directory:
    ```bash
    cd deployment/AWS-deployment
    ```
2. Install the Helm Chart:
    ```bash
    helm install my-release my-chart
    ```
3. List Helm Releases::
    ```bash
    helm ls
    ```

4. Verify the deployment:
    ```bash
    kubectl get pods
    ```

5. Port-Forward the Frontend Service:
    ```bash
    kubectl port-forward svc/frontend 8080:80
    ```

6. Access the Frontend Service:
    ```bash
    curl http://localhost:8080
    ```
    Or: Open a browser and navigate to `http://localhost:8080`.


6. Or: Access the Frontend Service:
    ```bash
    minikube service frontend
    ```

7. Uninstall the Helm Release:
    ```bash
    helm uninstall my-release
    ```

## Step 5: Access to All Services Through Ingress
This section covers deploying your Helm chart with access to all services through an Ingress.

1. Enable Ingress in Minikube:
    ```bash
    minikube addons enable ingress
    ```

2. Check Ingress Controller Pods:
    ```bash
    kubectl get pods -n ingress-nginx
    ```

3. Navigate to the Deployment Directory:
    ```bash
    cd deployment/AWS-deployment
    ```

4. Install the Helm Chart:
    ```bash
    helm install my-release my-chart
    ```

5. List Helm Releases:
    ```bash
    helm ls
    ```

6. Verify the deployment:
    ```bash
    kubectl get pods
    ```

7. Get the Ingress Details:
    ```bash
    kubectl get ingress
    ```

8. Start minikube tunnel:
    ```bash
    minikube tunnel
    ```

9. Test the ingress: (you can use multiple endpoints for each of the different services)
    ```bash
    curl --resolve "mylocaltestsite.local:80:127.0.0.1" -i http://mylocaltestsite.local/user-data/submit
    ```

## Cleaning up:
1. Uninstall the Helm Release:
    ```bash
    helm uninstall my-release
    ```
2. Stop Minikube:
    ```bash
    minikube stop
    ```