# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "aws_acm_certificate_us_east_1_arn" {
    description = "AWS SSL certificate ARN"
    type = string
}

variable "aws_route53_hosted_zone_id" {
    description = "AWS Route 53 Hosted Zone ID"
    type = string
}

variable "green_bird_www_domain" {
  description = "Frontend Domain"
  type = string
}

variable "green_bird_api_domain" {
  description = "Backend Domain"
  type = string
}

variable "auth_cookie_domain" {
  description = "Cookie Domain"
  type = string
}
