provider "aws" {
  region = var.region
}

# create s3 static site
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.environment}-website-bucket"
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# polece open file
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "s3:GetObject",
        Effect    = "Allow",
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*",
        Principal = "*"
      }
    ]
  })
}

# CloudFront to S3
resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id   = "S3-origin"
  }

  enabled = true
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-origin"
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}



# create S3  to Terraform
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "${var.environment}-terraform-state-bucket"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "retain"
    enabled = true

    noncurrent_version_transition {
      storage_class = "GLACIER"
      days          = 30
    }

    noncurrent_version_expiration {
      days = 365
    }
  }

  tags = {
    Name        = "${var.environment}-terraform-state-bucket"
    Environment = var.environment
  }
}

# create DynamoDB to Terraform
resource "aws_dynamodb_table" "terraform_lock_table" {
  name         = "${var.environment}-terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.environment}-terraform-lock-table"
    Environment = var.environment
  }
}
