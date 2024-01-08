variable "repository_read_access_arns" {
  description = "The ARNs of the IAM users/roles that have read access to the repository"
  type        = list(string)
  default     = ["arn:aws:iam::121850521501:user/bob"]
}

variable "repository_lambda_read_access_arns" {
  description = "The ARNs of the Lambda service roles that have read access to the repository"
  type        = list(string)
  default     = []
}

variable "repository_read_write_access_arns" {
  description = "The ARNs of the IAM users/roles that have read/write access to the repository"
  type        = list(string)
  default     = ["arn:aws:iam::121850521501:user/github-actions"]
}