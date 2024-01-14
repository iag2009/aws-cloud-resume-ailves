/* Inputs.tfvars */
variable "aws_account" {
  description = "aws_account"
  type        = string
}
variable "aws_region" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
}
variable "aws_region_repl" {
  description = "aws region"
  type        = string
  default     = "us-east-1"
}
variable "regions" {
  type    = list(string)
  default = ["us-east-1", "us-east-1"]
}
variable "solution" {
  description = "Name of Top level solution"
  type        = string
  default     = "ailves"
}
variable "environment" {
  description = "Name of env: dev or uat environment"
  type        = string
  default     = "dev"
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
/* end inputs.tfvars */
variable "s3_force_destroy" {
  type        = bool
  description = "a passthrough variable to the created s3 buckets to allow the terraform destroy to succeed in the event that objects are present"
  default     = true
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
