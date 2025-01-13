terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.54.1"
    }
  }
}
// S3 Bucket to store frontend files
resource "aws_s3_bucket" "frontend" {
  bucket = "green-bird-frontend-bucket-${random_id.bucket_suffix.hex}"

  # Enforce bucket ownership
  force_destroy = true
  tags = {
    Name = "GreenBirdFrontendBucket"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

// Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

// Policy to allow CloudFront access to the bucket
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.s3.iam_arn
        },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

// Build login redirect file from template
resource "local_file" "login_redirect_html" {
  filename = "${path.module}/files/login.html"
  content = templatefile("${path.module}/templates/login.html.tpl", {
    COGNITO_LOGIN_URL = "https://${var.cognito_domain}/oauth2/authorize?response_type=code&client_id=${var.cognito_client_id}&redirect_uri=${urlencode("https://${var.green_bird_api_domain}/auth/callback")}"
  })
}

// Upload the files to the S3 bucket
resource "aws_s3_object" "login_frontend_files" {
  for_each = fileset("${path.module}/files", "**/*")

  bucket       = aws_s3_bucket.frontend.id
  key          = each.key
  source       = "${path.module}/files/${each.key}"
  content_type = lookup(
    var.mime_types,
    regex("[.][^.]+$", each.key),  # Extract file extension
    "application/octet-stream"    # Default MIME type
  )
  etag = filemd5("${path.module}/files/${each.key}")
}

// App dist
resource "aws_s3_object" "app_dist" {
  for_each = fileset("${path.module}/app/dist", "**/*")

  bucket       = aws_s3_bucket.frontend.id
  key          = each.key
  source       = "${path.module}/app/dist/${each.key}"
  content_type = lookup(
    var.mime_types,
    regex("[.][^.]+$", each.key),  # Extract file extension
    "application/octet-stream"    # Default MIME type
  )
  etag = filemd5("${path.module}/app/dist/${each.key}")
}

resource "aws_cloudfront_origin_access_identity" "s3" {
  comment = "OAI for CloudFront to access S3"
}

resource "aws_cloudfront_distribution" "auth_frontend" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.frontend.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.s3.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled      = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"
    viewer_protocol_policy = "redirect-to-https"
    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn = aws_lambda_function.edge_authorizer.qualified_arn
    }
    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.aws_acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  aliases = [var.green_bird_www_domain]
}

resource "aws_cloudfront_origin_access_control" "s3" {
  name          = "frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                   = "always"
  signing_protocol                   = "sigv4"
}

resource "aws_route53_record" "www" {
  zone_id = var.aws_route53_hosted_zone_id
  name    = var.green_bird_www_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.auth_frontend.domain_name
    zone_id                = aws_cloudfront_distribution.auth_frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "GreenBirdFrontendAuthorizerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      },
      {
        Effect    = "Allow",
        Principal = { Service = "edgelambda.amazonaws.com" },
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "GreenBirdFrontendAuthorizerRolePolicy"
  role   = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow fetching parameters from AWS SSM Parameter Store
      {
        Effect   = "Allow",
        Action   = [
          "ssm:GetParameter"
        ],
        Resource = [
          "arn:aws:ssm:*:*:parameter/cognito/green_bird_region",
          "arn:aws:ssm:*:*:parameter/cognito/green_bird_user_pool_id",
          "arn:aws:ssm:*:*:parameter/cognito/green_bird_client_id"
        ]
      },
      # Allow logging to CloudWatch Logs
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "edge_authorizer" {
  function_name = "GreenBirdFrontendAuthorizer"
  runtime       = "python3.12"
  handler       = "authorizer.handler"
  role = aws_iam_role.lambda_role.arn
  filename      = "${path.module}/lambda_edge_authorizer/dist/authorizer.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_edge_authorizer/dist/authorizer.zip")
  publish = true
}
