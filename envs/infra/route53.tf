## Provides a Route53 query logging configuration resource
resource "aws_route53_query_log" "route53" {
  zone_id = data.aws_route53_zone.this.zone_id

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.route53.arn
}
## Create CloudWatch log group for Route 53
resource "aws_cloudwatch_log_group" "route53" {
  provider          = aws.us-east-1
  name              = "/aws/route53/${data.aws_route53_zone.this.name}"
  retention_in_days = 30
}
