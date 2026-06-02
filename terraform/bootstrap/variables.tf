variable "aws_region" {
  description = "AWS region where the state bucket lives. Must match the backend region of terraform/aws."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique name for the S3 bucket that holds the Terraform state of terraform/aws."
  type        = string
  default     = "pin-equipo4-tfstate"
}
