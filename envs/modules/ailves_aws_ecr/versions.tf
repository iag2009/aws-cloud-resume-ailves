terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.22"
      configuration_aliases = [ aws.instancemaker ]
    }
  }
}
