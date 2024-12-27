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
 * Login gets it own Lambda function
 */
data "archive_file" "lambda_login" {
  type = "zip"
  source_dir = "${path.module}/login"
  output_path = "${path.module}/login.zip"
}

resource "aws_s3_object" "lambda_login" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "login.zip"
  source = data.archive_file.lambda_login.output_path
  etag = filemd5(data.archive_file.lambda_login.output_path)
}

/*
 * Upload login.html to the same S3 bucket
 */
resource "aws_s3_object" "login_html" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "templates/login.html" # File name in the bucket
  source = "${path.module}/login/templates/login.html" # Path to the local login.html file

  content_type = "text/html"
  etag         = filemd5("${path.module}/login/templates/login.html") # Compute the MD5 hash of the file
  cache_control = "no-cache, no-store, must-revalidate"
}

resource "aws_iam_policy" "lambda_s3_access" {
  name = "LambdaS3Access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.lambda_bucket.arn}/templates/login.html"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}

resource "aws_lambda_function" "login" {
  function_name = "GreenBirdLogin"
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_login.key
  runtime = "python3.12"
  handler = "login_function.handler"
  source_code_hash = data.archive_file.lambda_login.output_base64sha256
  role = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.lambda_bucket.id
    }
  }
}

resource "aws_cloudwatch_log_group" "green-bird-login-log-group" {
  name = "/aws/lambda/${aws_lambda_function.login.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw_login" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${var.api_gateway_api_execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "web_login" {
  api_id = var.api_gateway_api_id
  integration_uri    = aws_lambda_function.login.invoke_arn
  integration_type   = "AWS_PROXY"
  connection_type    = "INTERNET"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "web_login" {
  api_id = var.api_gateway_api_id
  route_key = "GET /login"
  target = "integrations/${aws_apigatewayv2_integration.web_login.id}"
  authorization_type = "NONE"
}

/*
 * Application Lambda starts here
 */
data "archive_file" "lambda_web" {
  type = "zip"
  source_dir  = "${path.module}/web"
  output_path = "${path.module}/web.zip"
}

resource "aws_s3_object" "lambda_web" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "web.zip"
  source = data.archive_file.lambda_web.output_path
  etag = filemd5(data.archive_file.lambda_web.output_path)
}

resource "aws_lambda_function" "web" {
  function_name = "GreenBirdWeb"
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key    = aws_s3_object.lambda_web.key
  runtime = "python3.12"
  handler = "web_function.handler"
  source_code_hash = data.archive_file.lambda_web.output_base64sha256
  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "green-bird-web-log-group" {
  name = "/aws/lambda/${aws_lambda_function.web.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.web.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${var.api_gateway_api_execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "web" {
  api_id = var.api_gateway_api_id

  integration_uri    = aws_lambda_function.web.invoke_arn
  integration_type   = "AWS_PROXY"
  connection_type    = "INTERNET" 
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "web" {
  api_id = var.api_gateway_api_id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.web.id}"
  authorization_type = "JWT"
  authorizer_id = var.api_gateway_authorizer_id
}
