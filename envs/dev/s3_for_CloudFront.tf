locals {
  bucket_name = "${var.project_long}-${var.environment}-source"
}

/** Source bucket for the static web site **/
module "s3_bucket" {
  source        = "../modules/s3_bucket"
  bucket        = local.bucket_name
  acl           = var.s3_acl # "private"
  force_destroy = var.s3_force_destroy
  versioning    = var.s3_versioning
  logging = {
    target_bucket = var.s3_logging["target_bucket"]
    target_prefix = "s3-${var.project}-logs/"
  }
  control_object_ownership = var.s3_control_object_ownership
  object_ownership         = var.s3_object_ownership

  attach_policy = var.s3_attach_policy

  /**
   * Versioning was on with no rotation rule: by September 2026 the bucket held
   * 213 versions totalling 3.6 GB behind 11 current objects.
   * Keep three previous versions for at most 30 days and clean up incomplete
   * multipart uploads.
   **/
  lifecycle_rule = [
    {
      id      = "expire-noncurrent-versions"
      enabled = true

      abort_incomplete_multipart_upload_days = 7

      noncurrent_version_expiration = {
        newer_noncurrent_versions = 3
        days                      = 30
      }
    }
  ]
}
