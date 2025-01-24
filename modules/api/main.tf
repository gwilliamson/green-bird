/*
 * An IAM role for executing lambdas
 */
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda_api"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
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

/*
 * IAM Policy for CloudWatch Logs
 */
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "serverless_lambda_api_logs"
  description = "Policy to allow Lambda function to write to CloudWatch logs"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Action: [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource: "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

# =============================================================================
# User Lambda starts here
# =============================================================================
resource "aws_lambda_function" "user_api" {
  function_name    = "UserApi"
  runtime          = "python3.12"
  handler          = "user_lambda.handler"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "${path.module}/user/dist/handler.zip"
  source_code_hash = filebase64sha256("${path.module}/user/dist/handler.zip")
}

resource "aws_cloudwatch_log_group" "api_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.user_api.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_protected" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.user_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_api_execution_arn}/*/GET/user"
}

resource "aws_apigatewayv2_integration" "user_api_integration" {
  api_id           = var.api_gateway_api_id
  integration_uri  = aws_lambda_function.user_api.invoke_arn
  integration_type = "AWS_PROXY"
}

resource "aws_apigatewayv2_route" "get_user" {
  api_id    = var.api_gateway_api_id
  route_key = "GET /user"
  authorization_type = "CUSTOM"
  authorizer_id = var.api_gateway_cognito_authorizer_id
  target    = "integrations/${aws_apigatewayv2_integration.user_api_integration.id}"
}
