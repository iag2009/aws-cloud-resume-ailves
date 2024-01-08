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
variable "replication_aws_region" {
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

