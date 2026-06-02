terraform {
  # >= 1.10 for native S3 state locking (use_lockfile), no DynamoDB needed.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3 so the state survives between CI runs (apply/destroy
  # must be repeatable). The bucket is created once by terraform/bootstrap.
  # Backend config cannot use variables, so these are literals; keep the
  # region in sync with terraform/bootstrap and the AWS_REGION secret.
  backend "s3" {
    bucket       = "pin-equipo4-tfstate"
    key          = "aws/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
