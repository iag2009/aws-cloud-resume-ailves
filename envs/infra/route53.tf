/**
 * Route 53 query logging is disabled.
 *
 * Logging DNS queries for a personal site into CloudWatch buys nothing and
 * costs ingestion ($0.50/GB): by September 2026 the /aws/route53/ailves2009.com
 * group held 3.7 MB of records that nobody read. If an investigation ever
 * needs it, it can be turned back on in a minute.
 *
 * Removed:
 *   resource "aws_route53_query_log" "route53"
 *   resource "aws_cloudwatch_log_group" "route53"
 */
