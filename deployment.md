# Kubernetes Cluster Live Testing Guide on AWS

This guide will help set up a Kubernetes cluster on AWS using Terraform, kOps and Helm, and test the deployments with strict frontend access or through an Ingress with the provided URL.

## Step 1: Install `kubectl`

Follow the official [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/) for your operating system.

Verify the installation:

```bash
kubectl version --client
```

## Step 2: Install `AWS CLI`

Follow the official [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) for your operating system. Also configure the AWS CLI with your credentials and ensure they can be accessed by Terraform and kOps:

```bash
aws configure
```

## Step 3: Install `kOps`

Follow the official [kOps installation guide](https://kops.sigs.k8s.io/getting_started/install/) for your operating system.

Verify the installation:

```bash
kops version
```

## Step 4: Install `Terraform`

Follow the official [Terraform installation guide](https://learn.hashicorp.com/tutorials/terraform/install-cli) for your operating system.

Verify the installation:

```bash
terraform version
```

## Step 5: Provision an S3 Bucket for Terraform State (Strongly recommended but optional)

It is strongly recommended to use an S3 bucket to store the Terraform state file. This ensures that the state file is stored securely and can be accessed by multiple team members. To create an S3 bucket, run the following commands:

```bash
aws s3api create-bucket --bucket (your bucket name) --region (your region)
```

## Step 6: Generate SSH Key Pair (Requied if you plan on using a bastion host)

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

## Step 7: Deploy the Terraform Infrastructure

1. Navigate to the Terraform Directory:

```bash
cd terraform-files
```

2. Initialize Terraform:

If using the S3 bucket for the Terraform state, run the following command:

```bash
terraform init -backend-config="bucket=my-terraform-state-bucket" \
               -backend-config="key=prod/terraform.tfstate" \
               -backend-config="region=us-east-2"
```

Otherwise: 

```bash
terraform init
```

3. Deploy the Terraform Infrastructure:

Note: please ensure in the following command that all the variables are set correctly, please use full directory paths for the ssh_key_path and config_path variables, the configuration below has been set to default values to show the configuration format.

```bash
terraform apply -var="aws_region=ca-central-1" \
				-var="az_count=3" \
				-var="use_ingress_controller=false" \
				-var="environment_name=dev" \
				-var="namespace=AWS-Deployment" \
				-var="deployment_name=AWS-Deployment" \
				-var="vpc_name=vpc-dev" \
				-var="ssh_key_path=/home/user/.ssh/id_rsa.pub" \
				-var="config_path=/home/user/.kube/config" \
				-var="enable_bastion=false" \
				-auto-approve
```

3. After the deployment is complete, you will see the output with the Kubernetes cluster details.

## Step 8: Cleaning Up:

1. Before running terraform destroy, you should manually delete the kOps cluster by running:

```bash
kops delete cluster --name your-cluster-name --state s3://your-kops-state-store --yes
```
After waiting a couple of minutes, the last line output should be: 
```
deleted cluster: your-cluster-name
```

2. Destroy the Terraform Infrastructure:

```bash
terraform destroy
	- yes
```