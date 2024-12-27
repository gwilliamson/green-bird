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
  handler = "lambda_function.handler"

  source_code_hash = data.archive_file.lambda_web.output_base64sha256

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_cloudwatch_log_group" "green-bird-web" {
  name = "/aws/lambda/${aws_lambda_function.web.function_name}"

  retention_in_days = 30
}

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

resource "aws_apigatewayv2_route" "web" {
  api_id = var.api_gateway_api_id

  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.web.id}"
  authorization_type = "JWT"
  authorizer_id = var.api_gateway_authorizer_id
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