## Create a random pet name
resource "random_pet" "this" {
  length = 1
}
## Create a Secret in Secrets Manager
resource "aws_secretsmanager_secret" "site_secrets" {
  name = "${random_pet.this.id}-site-secrets"
}
## Create a Admin Name parameter in Secret Manager
resource "aws_secretsmanager_secret_version" "admin_name" {
  secret_id = aws_secretsmanager_secret.site_secrets.id
  secret_string = jsonencode({
    admin_name = "admin"
  })
}
## Create a Domain Name parameter in Secret Manager
resource "aws_secretsmanager_secret_version" "domain_name" {
  secret_id     = aws_secretsmanager_secret.site_secrets.id
  secret_string = var.domain_name
}
## Create a Domain Name parameter in SSM Parameter Store
resource "aws_ssm_parameter" "domain_name" {
  name        = "/${var.project}/${var.environment}/parameters/domain_name"
  description = "The domain name for the application"
  type        = "SecureString"
  value       = aws_secretsmanager_secret_version.domain_name.secret_string
}
