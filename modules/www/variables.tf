variable "api_gateway_api_id" {
  description = "ID of the API Gateway API"
}

variable "api_gateway_api_execution_arn" {
    description = "API Gateway Execution ARN"
}

variable "api_gateway_authorizer_id" {
    description = "ID of the API Gateway Authorizer"
}

variable "cognito_domain" {
  description = "Cognito Domain"
}

variable "cognito_app_client_id" {
  description = "ID of the Cognito App Client"
}

variable "cognito_issuer" {
  description = "URI of Cognito Issuer"
}

variable "redirect_uri" {
  description = "URI to redirect to upon successful auth"
  default = "https://www.gerg.ing/app"
}