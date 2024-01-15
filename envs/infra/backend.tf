terraform {
  backend "s3" {
    bucket         = "ailves-2009-terraform-state"
    key            = "aws-common.tfstate"
    region         = "us-east-2"
    dynamodb_table = "ailves-tf-state-lock"
    encrypt        = "false"
  }

  required_version = ">= 0.13.1"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.0"
    }
  }
}
## Provider in var.aws_region_repl for replicas (S3, ECR, ..) in Europe
provider "aws" {
  alias  = "replica"
  region = var.aws_region_repl
  default_tags {
    tags = {
      ENV            = var.environment
      Solution       = var.solution
      Project        = var.project
      Gitlab_project = var.gitlab_project
      ManagedBy      = "terraform"
      workspace      = terraform.workspace
    }
  }
  # Make it faster by skipping something
  #skip_metadata_api_check     = true
  #skip_region_validation      = true
  #skip_credentials_validation = true
  #skip_requesting_account_id  = true
}
## Second provider for ACM certificates, and ECR repositories, which must be in us-east-1
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
  default_tags {
    tags = {
      ENV            = var.environment
      Solution       = var.solution
      Project        = var.project
      Gitlab_project = var.gitlab_project
      ManagedBy      = "terraform"
      workspace      = terraform.workspace
    }
  }
}
## Main provider in var.aws_region
provider "aws" {
  region = var.aws_region
  # profile = "da-sb"   # Who will get access to destination account
  /* assume_role {
    role_arn     = "arn:aws:iam::${var.DEPLOY_INTO_ACCOUNT_ID}:role/TerraformRole"
    session_name = "Terraform"
    external_id  = "${var.ASSUME_ROLE_EXTERNAL_ID}"
  } */

  # Make it faster by skipping something
  #skip_metadata_api_check     = true
  #skip_region_validation      = true
  #skip_credentials_validation = true
  #skip_requesting_account_id  = true

  default_tags {
    tags = {
      ENV            = var.environment
      Solution       = var.solution
      Project        = var.project
      Gitlab_project = var.gitlab_project
      ManagedBy      = "terraform"
      workspace      = terraform.workspace
    }
  }
}

