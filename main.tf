provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project-name = "green-bird"
    }
  }

}

module "cognito" {
  source = "./modules/cognito"
}

module "apigateway" {
  source = "./modules/apigateway"
  aws_acm_certificate_arn = var.aws_acm_certificate_arn
  aws_route53_hosted_zone_id = var.aws_route53_hosted_zone_id
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
  cognito_user_pool_endpoint = module.cognito.user_pool_endpoint
}

module "www" {
  source = "./modules/www"
  api_gateway_api_id = module.apigateway.id
  api_gateway_api_execution_arn = module.apigateway.execution_arn
  api_gateway_authorizer_id = module.apigateway.authorizer_id
  cognito_domain = module.cognito.cognito_domain
  cognito_app_client_id = module.cognito.user_pool_client_id
  cognito_issuer = module.cognito.cognito_issuer
}