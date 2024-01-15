locals {
  bucket_name = "ailves-2009-logs-us-east-2"
}

resource "aws_kms_key" "replica" {
  provider = aws.replica

  description             = "S3 bucket replication KMS key"
  deletion_window_in_days = 7
}

module "log_bucket" {
  # source  = "terraform-aws-modules/s3-bucket/aws"
  # version = "~> 2.0"
  source = "../modules/s3_bucket"


  bucket        = local.bucket_name
  acl           = "log-delivery-write"
  force_destroy = true

  control_object_ownership = var.s3_control_object_ownership
  object_ownership         = var.s3_object_ownership

  attach_elb_log_delivery_policy = true
  attach_lb_log_delivery_policy  = true
  attach_policy                  = var.s3_attach_policy
  policy                         = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLogDelivery",
      "Effect": "Allow",
      "Principal": {
        "Service": "delivery.logs.amazonaws.com"
      },
      "Action": [
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::${local.bucket_name}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
POLICY
}
