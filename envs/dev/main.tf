/*
module "s3" {
  source                  = "../modules/s3"
  aws_account             = var.aws_account
  aws_region              = var.aws_region
  replication_aws_region  = var.replication_aws_region
  bucket_name             = "${var.solution}-${var.project}-${var.environment}-source"
  //prevent_destroy         = false
  force_destroy           = true
  //s3_policy_service       = "cloudfront.amazonaws.com"
  //s3_policy_condition_arn = "cloudfront::${var.aws_account}:distribution/${aws_cloudfront_distribution.this.id}"
  tags = {
    Name = "${var.solution}-${var.project}-${var.environment}"
  }
  # Logging 
  // logs_prefix = "${var.logs_prefix}"

  # Replication

  //replication_enabled    = "${var.enable_replication}"
}
*/

