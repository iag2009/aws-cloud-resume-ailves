/* Inputs.tfvars */
variable "aws_account" {
  description = "aws_account"
  type        = string
}
variable "region" {
  description = "aws region"
  type        = string
  default     = "us-east-2"
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
/* end global vars */
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}
variable "public_subnets" {
  type        = list(string)
  description = "Available cidr blocks for public subnets."
}
variable "private_subnets" {
  type        = list(string)
  description = "Available cidr blocks for private subnets."
}
/* end inputs.tfvars */

variable "aws_ami" {
  description = "Depends on location"
  type        = string
  default     = "ami-01e7ca2ef94a0ae86"
}
variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ailves_instance"
}
variable "sqs" {
  type = object({
    name   = string
    enable = bool
  })
  default = ({
    name   = "sqs_service"
    enable = true
  })
}
