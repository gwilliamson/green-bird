/*
 * S3 Bucket for Lambda function code
 */
resource "random_pet" "lambda_bucket_name" {
  prefix = "green-bird"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "lambda_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "lambda_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.lambda_bucket]

  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

/*
 * An IAM role for executing lambdas
 */
resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"
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

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

/*
 * App Lambda starts here
 */
data "archive_file" "lambda_app" {
  type = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/app.zip"
}

resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "app.zip"
  source = data.archive_file.lambda_app.output_path
  etag = filemd5(data.archive_file.lambda_app.output_path)
}

resource "aws_lambda_function" "app" {
  function_name = "GreenBirdApp"
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_app.key
  runtime = "python3.12"
  handler = "app.handler"
  source_code_hash = data.archive_file.lambda_app.output_base64sha256
  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "green-bird-app-log-group" {
  name = "/aws/lambda/${aws_lambda_function.app.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_login" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${var.api_gateway_api_execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "app_integration" {
  api_id = var.api_gateway_api_id
  integration_uri    = aws_lambda_function.app.invoke_arn
  integration_type   = "AWS_PROXY"
  connection_type    = "INTERNET"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "app" {
  api_id = var.api_gateway_api_id
  route_key = "GET /app"
  target    = "integrations/${aws_apigatewayv2_integration.app_integration.id}"
  authorization_type = "JWT"
  authorizer_id = var.api_gateway_authorizer_id
}
/*
 * Auth Lambda starts here
 */
data "archive_file" "lambda_auth" {
  type = "zip"
  source_dir  = "${path.module}/auth"
  output_path = "${path.module}/auth.zip"
}

resource "aws_s3_object" "lambda_auth" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "auth.zip"
  source = data.archive_file.lambda_auth.output_path
  etag = filemd5(data.archive_file.lambda_auth.output_path)
}

resource "aws_lambda_function" "auth_redirect" {
  function_name = "GreenBirdAuth"
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_auth.key
  runtime = "python3.12"
  handler = "auth_redirect_function.handler"
  source_code_hash = data.archive_file.lambda_auth.output_base64sha256
  role = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      COGNITO_DOMAIN    = var.cognito_domain
      COGNITO_CLIENT_ID = var.cognito_app_client_id
      REDIRECT_URI      = var.redirect_uri
      COGNITO_ISSUER    = var.cognito_issuer
    }
  }

}

resource "aws_cloudwatch_log_group" "green-bird-auth-log-group" {
  name = "/aws/lambda/${aws_lambda_function.auth_redirect.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_redirect.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${var.api_gateway_api_execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "auth_integration" {
  api_id = var.api_gateway_api_id

  integration_uri    = aws_lambda_function.auth_redirect.invoke_arn
  integration_type   = "AWS_PROXY"
  connection_type    = "INTERNET" 
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "root" {
  api_id = var.api_gateway_api_id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.auth_integration.id}"
}
