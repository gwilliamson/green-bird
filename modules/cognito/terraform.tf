terraform {

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.54.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7.0"
    }
  }

  required_version = "~> 1.10"
}

