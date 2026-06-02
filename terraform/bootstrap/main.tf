# Remote state backend for the terraform/aws module.
#
# This module bootstraps the S3 bucket that stores the state of the main aws
# module. It is the one piece that cannot live in that module (it would need a
# state to create the thing that holds its own state), so it runs standalone
# with a local state. Run it once; the bucket then outlives apply/destroy
# cycles of terraform/aws, so the main module can be applied and destroyed
# repeatably from CI.

resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # The state can contain secrets in plain text and must not be destroyed by
  # accident: it is the source of truth for what the aws module created.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project = "pin-equipo4"
    Purpose = "terraform-remote-state"
  }
}

# Keep every state revision: lets us roll back if an apply corrupts the state.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# The state is sensitive: block all public access.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Reject any non-TLS request: the state can contain secrets, so it must never
# travel over plain HTTP.
resource "aws_s3_bucket_policy" "tfstate_tls_only" {
  bucket = aws_s3_bucket.tfstate.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.tfstate.arn,
        "${aws_s3_bucket.tfstate.arn}/*",
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

# Note: S3 server access logging is intentionally omitted. It would need a
# second log-delivery bucket, which is overkill for a single-team PIN state
# store. CloudTrail data events cover audit needs if ever required.
