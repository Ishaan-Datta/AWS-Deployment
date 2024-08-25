variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "tags" {
    description = "The tags to apply to the S3 bucket"
    type        = map(string)
}