resource "aws_apigatewayv2_api" "gateway" {
  name          = "GreenBirdApiGateway"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["Cookie", "Content-Type"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_origins = ["https://${var.green_bird_api_domain}", "https://${var.green_bird_www_domain}"]
    allow_credentials = true
    expose_headers = ["Set-Cookie"]
    max_age = 3600
  }
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    project-name = "green-bird"
  }
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id = aws_apigatewayv2_api.gateway.id
  name        = "v1" // TODO: parameterize this for other stages like dev-v1, qa-v1, etc.
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
    })
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = var.green_bird_api_domain
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
  stage = aws_apigatewayv2_stage.stage.id
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_route53_record" "api_record" {
  zone_id = var.aws_route53_hosted_zone_id
  name    = var.green_bird_api_domain
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

# Specify the Lambda execution role
resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  # Attach basic Lambda permissions
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_iam_role_policy" "lambda_logging_policy" {
  name   = "lambda_logging_policy"
  role   = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Create the Lambda function using the built archive
resource "aws_lambda_function" "authorizer_lambda" {
  function_name = "GreenBirdAPIAuthorizer"
  runtime       = "python3.12"
  handler       = "authorizer.handler"
  role          = aws_iam_role.lambda_execution_role.arn
  filename      = "${path.module}/lambda_authorizer/dist/authorizer.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_authorizer/dist/authorizer.zip")

  environment {
    variables = {
      COGNITO_USER_POOL_ID = var.cognito_user_pool_id
      COGNITO_CLIENT_ID = var.cognito_client_id
    }
  }
}

# Grant API Gateway permissions to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  api_id           = aws_apigatewayv2_api.gateway.id
  name             = "GreenBirdAPIAuthorizer"
  authorizer_type  = "REQUEST"
  authorizer_uri   = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${aws_lambda_function.authorizer_lambda.arn}/invocations"
  identity_sources = ["$request.header.Cookie"]  # Extract the token from the Cookie header
  authorizer_payload_format_version   = "2.0"  # Specify the required payload format version
}

