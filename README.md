# AWS_Deployment

try the [local installation guide](installation.md) first

## Overview of Helm Chart
...

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

## Overview of Terraform plan
main.tf: Defines resources and configurations.

variables.tf: Contains variable definitions.

outputs.tf: Specifies outputs from Terraform.

provider.tf: Configures the AWS provider.

## Installation/Deployment

See the [live cloud deployment](deployment.md) guide for detailed instructions on deploying the application to AWS.