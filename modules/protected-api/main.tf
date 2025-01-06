/*
 * S3 Bucket for Lambda function code
 * TODO: A bucket is unnecessary. Package the zip like in the other modules.
 */
resource "random_pet" "lambda_bucket_name" {
  prefix = "green-bird-protected"
  length = 2
}

resource "aws_s3_bucket" "protected_api_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_ownership_controls" "protected_api_bucket_ownership" {
  bucket = aws_s3_bucket.protected_api_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "protected_api_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.protected_api_bucket_ownership]

  bucket = aws_s3_bucket.protected_api_bucket.id
  acl    = "private"
}

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
      },
      {
        Effect: "Allow",
        Action: [
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.protected_api_bucket.arn}/*"
      },
      {
        Effect: "Allow",
        Action: [
          "s3:ListBucket"
        ],
        Resource = "${aws_s3_bucket.protected_api_bucket.arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs_policy_attachment" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

/*
 * Protected API Lambda starts here
 */
data "archive_file" "lambda_app" {
  type        = "zip"
  source_dir  = "${path.module}/protected"
  output_path = "${path.module}/protected.zip"
}

resource "aws_s3_object" "lambda_app" {
  bucket = aws_s3_bucket.protected_api_bucket.id
  key    = "protected.zip"
  source = data.archive_file.lambda_app.output_path
  etag   = filemd5(data.archive_file.lambda_app.output_path)
}

resource "aws_lambda_function" "protected_api" {
  function_name    = "ProtectedEndpoint"
  s3_bucket        = aws_s3_bucket.protected_api_bucket.id
  s3_key           = aws_s3_object.lambda_app.key
  runtime          = "python3.9"
  handler          = "protected.handler"
  source_code_hash = data.archive_file.lambda_app.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
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
