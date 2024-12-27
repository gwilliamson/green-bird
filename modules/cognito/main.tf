provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      project-name = "green-bird"
    }
  }

}

resource "aws_cognito_user_pool" "gerg_ing_pool" {
  name = "gerg_ing_user_pool"
  email_verification_subject = "Your Verification Code"
  email_verification_message = "Please use the following code: {####}"
  alias_attributes           = ["email"]
  auto_verified_attributes   = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 6
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  username_configuration {
    case_sensitive = false
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 7
      max_length = 256
    }
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "name"
    required                 = true

    string_attribute_constraints {
      min_length = 3
      max_length = 256
    }
  }
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cognito_user_pool_client" "gerg_ing_client" {
  name = "gerg_ing_user_pool_client"
  user_pool_id  = aws_cognito_user_pool.gerg_ing_pool.id
  allowed_oauth_flows        = ["implicit"]
  allowed_oauth_scopes       = ["openid", "profile", "aws.cognito.signin.user.admin"]
  supported_identity_providers = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls              = ["https://www.gerg.ing/login"]
  logout_urls                = ["https://www.gerg.ing/logout"]
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cognito_user_pool_domain" "gerg_ing_domain" {
  domain       = "green-bird-app" # Replace with your preferred prefix
  user_pool_id = aws_cognito_user_pool.gerg_ing_pool.id
}



