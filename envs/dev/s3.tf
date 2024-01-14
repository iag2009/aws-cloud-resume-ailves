/*
provider "aws" {
  region = local.origin_region
  
  # Make it faster by skipping something
  #skip_metadata_api_check     = true
  #skip_region_validation      = true
  #skip_credentials_validation = true
  #skip_requesting_account_id  = true
}

provider "aws" {
  region = local.replica_region

  alias = "replica"

  # Make it faster by skipping something
  #skip_metadata_api_check     = true
  #skip_region_validation      = true
  #skip_credentials_validation = true
  #skip_requesting_account_id  = true
}
*/
locals {
  bucket_name             = "${var.project_long}-${var.environment}-source"
  destination_bucket_name = "${var.project_long}-${var.environment}-destination"
  #origin_region           = var.aws_region
  #replica_region          = var.aws_region_repl
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "replica" {
  provider = aws.replica

  description             = "S3 bucket replication KMS key"
  deletion_window_in_days = 7
}

module "replica_bucket" {
  #source = "../../../../terraform_aws_modules/terraform-aws-s3-bucket"

  source = "../../modules/s3"
  providers = {
    aws = aws.replica
  }

  bucket = local.destination_bucket_name
  acl    = "private"
  force_destroy = false

  versioning = {
    enabled = true
  }
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  attach_policy = false
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketOwnerEnforced",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${local.destination_bucket_name}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
POLICY
}

module "s3_bucket" {
  # source = "../../../../terraform_aws_modules/terraform-aws-s3-bucket"

  source = "../../modules/s3"
  bucket = local.bucket_name
  acl    = "private"
  force_destroy = false

  versioning = {
    enabled = true
  }
  
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  attach_policy = false
  /*
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BucketOwnerEnforced",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${local.bucket_name}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
POLICY
*/
  replication_configuration = {
    role = aws_iam_role.replication.arn

    rules = [
      {
        id       = "something-with-kms-and-filter"
        status   = true
        priority = 10

        delete_marker_replication = false

        source_selection_criteria = {
          replica_modifications = {
            status = "Enabled"
          }
          sse_kms_encrypted_objects = {
            enabled = true
          }
        }

        filter = {
          prefix = "one"
          tags = {
            ReplicateMe = "Yes"
          }
        }

        destination = {
          bucket        = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class = "STANDARD"

          replica_kms_key_id = aws_kms_key.replica.arn
          account_id         = data.aws_caller_identity.current.account_id

          access_control_translation = {
            owner = "Destination"
          }

          replication_time = {
            status  = "Enabled"
            minutes = 15
          }

          metrics = {
            status  = "Enabled"
            minutes = 15
          }
        }
      },
      {
        id       = "something-with-filter"
        priority = 20

        delete_marker_replication = false

        filter = {
          prefix = "two"
          tags = {
            ReplicateMe = "Yes"
          }
        }

        destination = {
          bucket        = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class = "STANDARD"
        }
      },
      {
        id       = "everything-with-filter"
        status   = "Enabled"
        priority = 30

        delete_marker_replication = true

        filter = {
          prefix = ""
        }

        destination = {
          bucket        = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class = "STANDARD"
        }
      },
      {
        id     = "everything-without-filters"
        status = "Enabled"

        delete_marker_replication = true

        destination = {
          bucket        = "arn:aws:s3:::${local.destination_bucket_name}"
          storage_class = "STANDARD"
        }
      },
    ]
  }
}
/*
module "object" {
  source = "../../modules/object"

  bucket = module.s3_bucket.s3_bucket_id
  key    = "key-local"

  file_source = "one.md"
  #  content = file("README.md")
  #  content_base64 = filebase64("README.md")

  tags = {
    Sensitive = "not-really"
  }
}
*/
resource "aws_s3_object" "this" {
  bucket        = module.s3_bucket.s3_bucket_id
  key           = "key-local"
  force_destroy = true

  acl    = "bucket-owner-full-control"

  source         = "one.md"
  # etag           = var.etag
}
/*
variable "source_dir" {
  type = string
  description = "The source directory to upload to S3"
  default = "${dirname(dirname(dirname(path.module)))}/website"
}
*/
#resource "aws_s3_object" "object" {
#  for_each = { for f in fileset(var.source_dir, "**/*") : f => f }
#  bucket = module.s3_bucket.s3_bucket_id
#  key    = each.value
#  source = "${var.source_dir}/${each.value}"
#  acl    = "bucket-owner-full-control"
#  etag   = filemd5("${var.source_dir}/${each.value}")
#}
