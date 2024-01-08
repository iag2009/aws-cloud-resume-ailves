/*
variable "aws_account" {
  type = string
  description = "the AWS account to deploy the S3 resources to"
}
variable "aws_region" {
  type        = string
  description = "the AWS region to deploy the S3 resources to"
  default = "us-east-2"
}
variable "replication_aws_region" {
  type        = string
  description = "the AWS region to deploy the replicated S3 resources to"
  default = "us-east-1"
}
variable "replication_enabled" {
  type = bool
  description = "if cross-region replication is desired"
  default = false
}
variable "bucket_name" {
  type        = string
  description = "name for the bucket that will host website"
}
variable "tags" {
  type        = map
  description = "optional tags to attach to the created s3 resources"
  default     = {}
}
variable "force_destroy" {
  default     = false
  description = "a passthrough variable to the created s3 buckets to allow the terraform destroy to succeed in the event that objects are present"
}
variable "prevent_destroy" {
  type = string
  description = "value for the s3 prevent destroy condition"
}
variable "s3_policy_condition_arn" {
  type = string
  description = "the arn of the s3 policy condition"  
}
variable "s3_policy_service" {
  type = string
  description = "the Service of the s3 policy condition"  
}
*/
