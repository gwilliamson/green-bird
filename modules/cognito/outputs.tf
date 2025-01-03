# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Output value definitions

output "user_pool_client_id" {
  description = "User pool client id"
  value = aws_cognito_user_pool_client.gerg_ing_client.id
}

output "user_pool_endpoint" {
  description = "User pool endpoint"
  value = aws_cognito_user_pool.gerg_ing_pool.endpoint
}

output "cognito_domain" {
  value = format(
    "%s.auth.%s.amazoncognito.com",
    aws_cognito_user_pool_domain.gerg_ing_domain.domain,
    var.aws_region
  )
}

output "cognito_issuer" {
  value = format(
    "https://cognito-idp.%s.amazonaws.com/%s",
    var.aws_region,
    aws_cognito_user_pool.gerg_ing_pool.id
  )
}
