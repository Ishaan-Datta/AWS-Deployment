# AWS-Deployment

## Overview of the Application

what it does 

links for other instruction pages
[home](README.md)

## Implementation Details



### Helm Chart

how it works
configmap
secrets
environment variables
liveness probes to help with startup and container running states
3 replicas to ensure high availability
- **Annotations:**
    
    - `nginx.ingress.kubernetes.io/rewrite-target: /$2`: This annotation specifies how to rewrite the request path. The `$2` captures the part of the path after the prefix. For example, `/auth/version` would be rewritten to `/version`.
    - `nginx.ingress.kubernetes.io/use-regex: "true"`: This annotation enables the use of regex in the `path` field, allowing for more flexible path matching and rewriting.
- **Path Definitions:**
    
    - `path: /auth(/|$)(.*)`: Matches `/auth`, `/auth/`, and any path starting with `/auth/`. The `(.*)` captures the remaining part of the path after `/auth/`.
- **Rewrite Target:**
    
    - The `$2` in the `rewrite-target` annotation corresponds to the captured part of the path after the prefix. So, `/auth/version` will match `/auth(/|$)(.*)`, and the `$2` portion will be `version`, effectively rewriting the path to `/version`.


### Kubernetes Cluster


### Terraform Infrastructure
how it works
Features:
- includes ability to distribute subnets across different availability zones for high availability
- instance security groups
- bastion host for enabling SSH access to the private subnets
- dynamically assigned subnets

## Installation/Deployment

### Local Installation

### Cloud Deployment
try the [local installation guide](installation.md) first
See the [live cloud deployment](deployment.md) guide for detailed instructions on deploying the application to AWS.

## Future Improvements

- hardening: 
	- internal load balancing
	- Cluster Autoscaler: curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-one-asg.yaml
	- kops can autoscale as well: The worker nodes will be part of an autoscaling group. Autoscaling will be managed by cluster-autoscaler.


    - Modifying the file to handle autoscaling 
- HTTPS certificate generation using traefik
- Utilizing EC2 spot instances with persisting states
- Implementing monitoring and logging for real-time cluster performance tracking and centralized log management/error tracking