resource "aws_s3_bucket" "kops_state_store" {
  bucket        = var.bucket_name
  force_destroy = true
  tags          = merge(var.tags, {
    Name        = var.bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "kops_state_store" {
  bucket                  = aws_s3_bucket.kops_state_store.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "kops_state_store" {
  bucket             = aws_s3_bucket.kops_state_store.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}