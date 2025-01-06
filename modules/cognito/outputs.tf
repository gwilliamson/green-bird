# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Output value definitions
output "user_pool_id" {
  description = "Cognito user pool id"
  value = aws_cognito_user_pool.green_bird_user_pool.id
}

output "cognito_client_id" {
  description = "Cognito user pool client id"
  value = aws_cognito_user_pool_client.green_bird_client.id
}

output "cognito_domain" {
  value = format(
    "%s.auth.%s.amazoncognito.com",
    aws_cognito_user_pool_domain.green-bird-domain.domain,
    var.aws_region
  )
}

output "cognito_issuer" {
  value = format(
    "https://cognito-idp.%s.amazonaws.com/%s",
    var.aws_region,
    aws_cognito_user_pool.green_bird_user_pool.id
  )
}
