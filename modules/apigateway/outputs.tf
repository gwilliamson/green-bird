output "base_url" {
  description = "Base URL for API Gateway stage."

  value = aws_apigatewayv2_stage.lambda.invoke_url
}

output "id" {
    description = "API Gateway API ID"
    value = aws_apigatewayv2_api.gateway.id
}

output "execution_arn" {
    description = "API Gateway API execution ARN"
    value = aws_apigatewayv2_api.gateway.execution_arn
}

output "authorizer_id" {
    description = "API Gateway Authorizer ID"
    value = aws_apigatewayv2_authorizer.auth.id
}