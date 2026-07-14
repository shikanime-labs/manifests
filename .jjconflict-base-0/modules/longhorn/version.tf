terraform {
  required_version = "~> 1.8"
  cloud {
    hostname     = "app.terraform.io"
    organization = "shikanime-studio"
    workspaces {
      name = "nishir-services"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.82"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.regions.aws_s3_bucket

  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  endpoints {
    s3 = var.endpoints.s3
  }
}
