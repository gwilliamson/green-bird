provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project-name = "green-bird"
    }
  }

}

/*
 * apigateway module
 * - AWS API Gateway resources
 * - Custom domain
 * - A Lambda authorizer
 */
module "apigateway" {
  source = "./modules/apigateway"
  aws_acm_certificate_arn = var.aws_acm_certificate_us_west_1_arn
  aws_route53_hosted_zone_id = var.aws_route53_hosted_zone_id
  cognito_user_pool_id = module.cognito.user_pool_id
  cognito_client_id = module.cognito.cognito_client_id
  green_bird_api_domain = var.green_bird_api_domain
  green_bird_www_domain = var.green_bird_www_domain
}

/*
 * cognito module
 * - AWS Cognito resources
 * - The auth callback Lambda
 */
module "cognito" {
  source = "./modules/cognito"
  api_gateway_api_id = module.apigateway.id
  api_gateway_api_execution_arn = module.apigateway.execution_arn
  auth_cookie_domain = var.auth_cookie_domain
  green_bird_api_domain = var.green_bird_api_domain
}

/*
 * login-page module
 * - An HTML page that redirects to Cognito
 * - Stored in S3
 * - Delivered by CloudFront
 * - Route53 record for www
 */
module "login-page" {
  source = "./modules/login-page"
  aws_acm_certificate_arn = var.aws_acm_certificate_us_east_1_arn
  aws_route53_hosted_zone_id = var.aws_route53_hosted_zone_id
  cognito_domain = module.cognito.cognito_domain
  cognito_client_id = module.cognito.cognito_client_id
  green_bird_api_domain = var.green_bird_api_domain
  green_bird_www_domain = var.green_bird_www_domain
}

/*
 * api module
 * - Lambda functions
 * - Fronted by the API Gateway from the apigateway module
 * - Protected by the Lambda authorizer from the apigateway module
 */
module "api" {
  source = "./modules/api"
  api_gateway_api_id = module.apigateway.id
  api_gateway_api_execution_arn = module.apigateway.execution_arn
  api_gateway_cognito_authorizer_id = module.apigateway.authorizer_id
}
