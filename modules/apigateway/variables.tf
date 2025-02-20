# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."

  type    = string
  default = "us-east-1"
}

variable "aws_acm_certificate_arn" {
  description = "AWS SSL certificate ARN"
  type = string
}

variable "aws_route53_hosted_zone_id" {
  description = "AWS Route 53 Hosted Zone ID"
  type = string
}

variable "green_bird_www_domain" {
  description = "Green Bird Backend Domain"
  type = string
}

variable "green_bird_api_domain" {
  description = "Green Bird Backend Domain"
  type = string
}

variable "cognito_user_pool_id" {
  description = "AWS Cognito User Pool ID"
  type = string
}

variable "cognito_client_id" {
  description = "AWS Cognito User Pool Client ID"
  type = string
}
