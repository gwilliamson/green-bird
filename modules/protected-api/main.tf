/*
 * An IAM role for executing lambdas
 */
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda_protected"
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
  name        = "serverless_lambda_protected_logs"
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

resource "aws_lambda_function" "protected_api" {
  function_name    = "ProtectedEndpoint"
  runtime          = "python3.9"
  handler          = "protected.handler"
  role             = aws_iam_role.lambda_exec.arn
  filename         = "${path.module}/protected/dist/protected.zip"
  source_code_hash = filebase64sha256("${path.module}/protected/dist/protected.zip")
}

resource "aws_cloudwatch_log_group" "protected_api_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.protected_api.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_protected" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.protected_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_api_execution_arn}/*/GET/protected"
}

resource "aws_apigatewayv2_integration" "protected_integration" {
  api_id           = var.api_gateway_api_id
  integration_uri  = aws_lambda_function.protected_api.invoke_arn
  integration_type = "AWS_PROXY"
}

resource "aws_apigatewayv2_route" "get_protected" {
  api_id    = var.api_gateway_api_id
  route_key = "GET /protected"
  authorization_type = "CUSTOM"
  authorizer_id = var.api_gateway_cognito_authorizer_id
  target    = "integrations/${aws_apigatewayv2_integration.protected_integration.id}"
}
