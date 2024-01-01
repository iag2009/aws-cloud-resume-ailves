resource "aws_secretsmanager_secret" "site_secrets" {
  name = "site_secrets"
}

resource "aws_secretsmanager_secret_version" "admin_name" {
  secret_id = aws_secretsmanager_secret.site_secrets.id
  secret_string = jsonencode({
    admin_name = "admin"
  })
}
resource "aws_secretsmanager_secret_version" "domain_name" {
  secret_id     = aws_secretsmanager_secret.site_secrets.id
  secret_string = var.domain_name
}

resource "aws_ssm_parameter" "domain_name" {
  name        = "/${var.project}/${var.environment}/parameters/domain_name"
  description = "The domain name for the application"
  type        = "SecureString"
  value       = aws_secretsmanager_secret_version.domain_name.secret_string
}
