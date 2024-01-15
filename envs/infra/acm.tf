/**  Create a wildcard certificate for domain names - aliases **/
resource "aws_acm_certificate" "wildcard" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = ["cv.${var.domain_name}", "${var.domain_name}"]
  validation_method         = "DNS"
  provider                  = aws.us-east-1
  tags = {
    Name = "Wildcard Certificate DNS zone"
  }
  lifecycle {
    create_before_destroy = true
  }
}
/** Data of DNS zone to have ID **/
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}
/** Create DNS records for validation ACM certificate **/
resource "aws_route53_record" "wildcard" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  #zone_id         = "*.${var.domain_name}"
  zone_id = data.aws_route53_zone.this.zone_id

  depends_on = [aws_acm_certificate.wildcard]
}
/** Create a validation for certificate **/
resource "aws_acm_certificate_validation" "this" {
  provider                = aws.us-east-1
  count                   = length(aws_acm_certificate.wildcard.*.arn) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.wildcard.arn
  validation_record_fqdns = [for record in aws_route53_record.wildcard : record.fqdn]
  depends_on              = [aws_acm_certificate.wildcard]
}