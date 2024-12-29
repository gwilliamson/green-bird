resource "aws_apigatewayv2_api" "gateway" {
  name          = "serverless_lambda_gw"
  protocol_type = "HTTP"
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.gateway.id
  name        = "v1"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_apigatewayv2_authorizer" "auth" {
  api_id           = aws_apigatewayv2_api.gateway.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-authorizer"
  jwt_configuration {
    audience = [ var.cognito_user_pool_client_id]
    issuer   = "https://${var.cognito_user_pool_endpoint}"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.gerg.ing"
  domain_name_configuration {
    certificate_arn = var.aws_acm_certificate_arn
    endpoint_type = "REGIONAL"
    security_policy = "TLS_1_2"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_apigatewayv2_api_mapping" "api_mapping" {
  api_id = aws_apigatewayv2_api.gateway.id
  domain_name = aws_apigatewayv2_domain_name.api.domain_name
  stage = aws_apigatewayv2_stage.lambda.id
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_route53_record" "api_record" {
  zone_id = var.aws_route53_hosted_zone_id
  name    = "api.gerg.ing"
  type    = "A"
  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.gateway.name}"
  retention_in_days = 30
}

