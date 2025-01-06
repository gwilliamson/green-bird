# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources."
  type    = string
  default = "us-west-1"
}

variable "api_gateway_api_id" {
  description = "ID of the API Gateway API"
  type = string
}

variable "api_gateway_api_execution_arn" {
  description = "API Gateway Execution ARN"
  type = string
}

variable "green_bird_api_domain" {
  description = "Backend domain"
  type = string
}

variable "auth_cookie_domain" {
  description = "Domain for cookies"
  type = string
}
