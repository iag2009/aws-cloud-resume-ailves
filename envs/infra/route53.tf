/**
 * Route 53 query logging отключён.
 *
 * Логирование DNS-запросов персонального сайта в CloudWatch не даёт ничего,
 * кроме расхода на ingestion ($0.50/ГБ): к сентябрю 2026 в группе
 * /aws/route53/ailves2009.com накопилось 3.7 МБ записей, которые никто
 * не читал. Если понадобится расследование — включается за минуту.
 *
 * Удалено:
 *   resource "aws_route53_query_log" "route53"
 *   resource "aws_cloudwatch_log_group" "route53"
 */
