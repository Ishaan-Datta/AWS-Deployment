terraform {
  required_providers {
    aws = {
      version = "4.67.0"
    }
  }
}

provider "aws" {
  alias = "us-east-1"
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "random_string" "random" {
  length  = 16
  lower   = true
  upper   = false
  special = false
  numeric = false
}

resource "aws_s3_bucket" "kops_bucket" {
  provider = aws.us-east-1
  bucket   = "${random_string.random.result}-kops-bucket"
}

resource "aws_s3_bucket_public_access_block" "example" {
  provider = aws.us-east-1
  bucket   = aws_s3_bucket.kops_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "example" {
  provider = aws.us-east-1
  bucket   = aws_s3_bucket.kops_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  provider = aws.us-east-1
  depends_on = [
    aws_s3_bucket_public_access_block.example,
    aws_s3_bucket_ownership_controls.example,
  ]

  bucket = aws_s3_bucket.kops_bucket.id
  acl    = "public-read"
}

output "s3_bucket" {
  value = aws_s3_bucket.kops_bucket.id
}

output "az" {
  value = data.aws_availability_zones.available.names[0]
}

// We're storing the cluster name in our Terraform state so that
// we don't have to use our shell's environment to remember it.
output "cluster_name" {
  value = "kops-cluster-${random_string.random.result}.k8s.local"
}
