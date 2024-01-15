/* Inputs.tfvars */
variable "aws_account" {
  description = "aws_account"
  type        = string
}
variable "aws_region" {
  description = "aws region"
  type        = string
}
variable "aws_region_repl" {
  description = "aws region"
  type        = string
}
variable "regions" {
  type    = list(string)
  default = ["us-east-1", "us-east-1"]
}
variable "solution" {
  description = "Name of Top level solution"
  type        = string
}
variable "environment" {
  description = "Name of env: dev or uat environment"
  type        = string
}
variable "project" {
  description = "Project Name"
  type        = string
}
variable "project_long" {
  description = "Long Name of Project"
  type        = string
}
variable "gitlab_project" {
  description = "Name of Project in Gitlab"
  type        = string
}
variable "domain_name" {
  description = "DNS Domain name"
  type        = string
}
/* vars for ECR */
variable "ecr_repository_read_access_arns" {
  description = "The ARNs of the IAM users/roles that have read access to the repository"
  type        = list(string)
  default     = ["arn:aws:iam::121850521501:user/bob"]
}

variable "ecr_repository_lambda_read_access_arns" {
  description = "The ARNs of the Lambda service roles that have read access to the repository"
  type        = list(string)
  default     = []
}

variable "ecr_repository_read_write_access_arns" {
  description = "The ARNs of the IAM users/roles that have read/write access to the repository"
  type        = list(string)
  default     = ["arn:aws:iam::121850521501:user/github-actions"]
}

variable "ecr_create" {
  description = "Determines whether resources will be created (affects all resources)"
  type        = bool
  default     = true
}

variable "ecr_repository_type" {
  description = "The type of repository to create. Either `public` or `private`"
  type        = string
  default     = "private"
}
variable "ecr_create_repository" {
  description = "Determines whether a repository will be created"
  type        = bool
  default     = true
}
variable "ecr_create_registry_policy" {
  description = "Determines whether a registry policy will be created"
  type        = bool
  default     = false
}
/* vars for S3 Bucket */
variable "s3_force_destroy" {
  type        = bool
  description = "a passthrough variable to the created s3 buckets to allow the terraform destroy to succeed in the event that objects are present"
  default     = true
}
variable "s3_acl" {
  description = "(Optional) The canned ACL to apply. Conflicts with `grant`"
  type        = string
  default     = null
}
variable "s3_control_object_ownership" {
  description = "Whether to manage S3 Bucket Ownership Controls on this bucket."
  type        = bool
  #default     = false
  default = true
}
variable "s3_object_ownership" {
  description = "Object ownership. Valid values: BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter. 'BucketOwnerEnforced': ACLs are disabled, and the bucket owner automatically owns and has full control over every object in the bucket. 'BucketOwnerPreferred': Objects uploaded to the bucket change ownership to the bucket owner if the objects are uploaded with the bucket-owner-full-control canned ACL. 'ObjectWriter': The uploading account will own the object if the object is uploaded with the bucket-owner-full-control canned ACL."
  type        = string
  #default     = "BucketOwnerEnforced"
  default = "BucketOwnerPreferred"
}
variable "s3_versioning" {
  description = "Map containing versioning configuration."
  type        = map(string)
  default     = {}
}
variable "s3_logging" {
  description = "Map containing access bucket logging configuration."
  type        = map(string)
  default     = {}
}
variable "s3_attach_policy" {
  description = "Controls if S3 bucket should have bucket policy attached (set to `true` to use value of `policy` as bucket policy)"
  type        = bool
  default     = false
}
