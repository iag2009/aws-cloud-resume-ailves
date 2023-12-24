terraform {
  backend "s3" {
    bucket         = "ailves-2009-terraform-state"
    key            = "aws-cloud-resume-ailves/dev/aws-cloud-resume-ailves.tfstate"
    region         = "us-east-2"
    dynamodb_table = "ailves-tf-state-lock"
    encrypt        = "false"
  }

  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
    }
  }
}

provider "aws" {
  # second provider for ACM certificates, which must be in us-east-1
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

provider "aws" {
  # alias   = "main"
  region = var.region
  # profile = "da-sb"   # Who will get access to destination account

  /* assume_role {
    role_arn     = "arn:aws:iam::${var.DEPLOY_INTO_ACCOUNT_ID}:role/TerraformRole"
    session_name = "Terraform"
    external_id  = "${var.ASSUME_ROLE_EXTERNAL_ID}"
  } */

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

data "aws_caller_identity" "main" {}
