/**
 * Application configuration parameters.
 *
 * This used to be Secrets Manager ($0.40 per secret per month) holding two
 * aws_secretsmanager_secret_version resources pointed at the same secret_id.
 * They overwrote each other on every apply, so the stored value was
 * non-deterministic. random_pet also made the secret name unguessable
 * ("eel-site-secrets"), so nothing ever tried to read it.
 *
 * Neither admin_name nor domain_name is a secret — domain_name is public by
 * definition. Only SSM Parameter Store Standard remains: it is free and gives
 * stable, predictable parameter names.
 */
resource "aws_ssm_parameter" "domain_name" {
  name        = "/${var.project}/${var.environment}/parameters/domain_name"
  description = "The domain name for the application"
  type        = "String"
  value       = var.domain_name

  tags = {
    Name = "${var.project}-${var.environment}-domain-name"
  }
}

resource "aws_ssm_parameter" "admin_name" {
  name        = "/${var.project}/${var.environment}/parameters/admin_name"
  description = "The administrator account name for the application"
  type        = "String"
  value       = var.admin_name

  tags = {
    Name = "${var.project}-${var.environment}-admin-name"
  }
}
