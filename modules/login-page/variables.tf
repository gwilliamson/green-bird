variable "mime_types" {
  default = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".json" = "application/json"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2" = "font/woff2"
  }
}

variable "aws_acm_certificate_arn" {
  description = "AWS SSL certificate ARN"
  type = string
}

variable "aws_route53_hosted_zone_id" {
  description = "AWS Route 53 Hosted Zone ID"
  type = string
}

variable "cognito_domain" {
  description = "Cognito Domain"
  type = string
}

variable "cognito_client_id" {
  description = "Cognito User Pool Client ID"
  type = string
}

variable "green_bird_api_domain" {
  description = "Backend domain"
  type = string
}

variable "green_bird_www_domain" {
  description = "Frontend domain"
  type = string
}