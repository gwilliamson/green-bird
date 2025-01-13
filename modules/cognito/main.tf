provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project-name = "green-bird"
    }
  }

}

resource "aws_cognito_user_pool" "green_bird_user_pool" {
  name = "GreenBirdUserPool"
  email_verification_subject = "Your Verification Code"
  email_verification_message = "Please use the following code: {####}"
  alias_attributes           = ["email"]
  auto_verified_attributes   = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  username_configuration {
    case_sensitive = false
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 7
      max_length = 256
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "name"
    required                 = true

    string_attribute_constraints {
      min_length = 3
      max_length = 256
    }
  }
  
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cognito_user_pool_client" "green_bird_client" {
  name = "GreenBirdUserPoolClient"
  user_pool_id  = aws_cognito_user_pool.green_bird_user_pool.id
  allowed_oauth_flows        = ["code"]
  allowed_oauth_scopes       = ["openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls              = ["https://${var.green_bird_api_domain}/auth/callback"]
  logout_urls                = ["https://${var.green_bird_api_domain}/logout"]
  generate_secret = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cognito_user_pool_domain" "green-bird-domain" {
  domain       = "green-bird"
  user_pool_id = aws_cognito_user_pool.green_bird_user_pool.id
}

resource "aws_ssm_parameter" "cognito_region" {
  name = "/cognito/green_bird_region"
  type = "String"
  value = var.aws_region
  description = "AWS region where the Cognito user pool lives"
}

resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name  = "/cognito/green_bird_user_pool_id"
  type  = "String"
  value = aws_cognito_user_pool.green_bird_user_pool.id
  description = "Cognito user pool id"
}

resource "aws_ssm_parameter" "cognito_client_secret" {
  name        = "/cognito/green_bird_client_secret"
  type        = "SecureString"
  value       = aws_cognito_user_pool_client.green_bird_client.client_secret
  description = "Cognito client secret"
}

resource "aws_ssm_parameter" "cognito_client_id" {
  name  = "/cognito/green_bird_client_id"
  type  = "String"
  value = aws_cognito_user_pool_client.green_bird_client.id
  description = "Cognito client id"
}

/*
 * Auth callback resources start here
 */

data "aws_caller_identity" "current" {}

/*
 * An IAM role for executing lambdas
 */
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ssm_access" {
  name   = "lambda_ssm_access_policy"
  role   = aws_iam_role.lambda_exec.name
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "ssm:GetParameter",
        Effect = "Allow",
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${aws_ssm_parameter.cognito_client_secret.name}"
      }
    ]
  })
}

/*
 * Auth callback Lambda starts here
 */
resource "aws_lambda_function" "auth_callback" {
  function_name = "GreenBirdAuthCallbackHandler"
  runtime   = "python3.12"
  handler   = "callback.handler"
  role = aws_iam_role.lambda_exec.arn
  filename      = "${path.module}/auth_callback/dist/callback.zip"
  source_code_hash = filebase64sha256("${path.module}/auth_callback/dist/callback.zip")
  environment {
    variables = {
      COGNITO_DOMAIN = aws_cognito_user_pool_domain.green-bird-domain.domain
      COGNITO_CLIENT_ID = aws_cognito_user_pool_client.green_bird_client.id
      CALLBACK_URI = "https://${var.green_bird_api_domain}/auth/callback"
      AUTH_COOKIE_DOMAIN = var.auth_cookie_domain
    }
  }
}

resource "aws_cloudwatch_log_group" "green-bird-app-log-group" {
  name = "/aws/lambda/${aws_lambda_function.auth_callback.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_login" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_callback.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${var.api_gateway_api_execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "auth_integration" {
  api_id           = var.api_gateway_api_id
  integration_uri  = aws_lambda_function.auth_callback.invoke_arn
  integration_type = "AWS_PROXY"
}

resource "aws_apigatewayv2_route" "auth_route" {
  api_id    = var.api_gateway_api_id
  route_key = "GET /auth/callback"
  target    = "integrations/${aws_apigatewayv2_integration.auth_integration.id}"
}


