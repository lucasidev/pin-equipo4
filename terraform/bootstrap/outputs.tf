output "state_bucket_name" {
  description = "Name of the S3 bucket holding the terraform/aws state. Use it in that module's backend block."
  value       = aws_s3_bucket.tfstate.id
}

output "state_bucket_region" {
  description = "Region of the state bucket. Must match the backend region of terraform/aws."
  value       = var.aws_region
}
