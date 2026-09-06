/**
 * Параметры конфигурации сайта.
 *
 * Раньше здесь был Secrets Manager ($0.40/секрет/мес) с двумя
 * aws_secretsmanager_secret_version на один и тот же secret_id — они
 * перетирали друг друга на каждом apply, поэтому значение секрета было
 * недетерминированным. Плюс random_pet делал имя секрета неугадываемым
 * ("eel-site-secrets"), так что прочитать его никто и не пытался.
 *
 * Ни admin_name, ни domain_name секретами не являются — domain_name вообще
 * публичен. Оставляем только SSM Parameter Store Standard: он бесплатен
 * и даёт стабильные, предсказуемые имена параметров.
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
