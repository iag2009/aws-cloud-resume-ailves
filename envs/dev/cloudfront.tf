/* Cloud Front Distribution, that only access s3 bucket */
/** S3 bucket policy for CloudFront to getting content **/
resource "aws_s3_bucket_policy" "this" {
  bucket = module.s3_bucket.s3_bucket_id

  lifecycle {
    prevent_destroy = false
  }
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "${module.s3_bucket.s3_bucket_arn}/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "arn:aws:cloudfront::${var.aws_account}:distribution/${aws_cloudfront_distribution.this.id}"
        }
      }
    }
  ]
}
EOF
}
/** First create a origin access identity for CloudFront Destribution **/
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project}_oai"
  description                       = "${var.project}_policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
/** Find a certificate issued by ACM **/
data "aws_acm_certificate" "wildcard" {
  domain      = "*.${var.domain_name}"
  provider    = aws.us-east-1
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}
/** Data of DNS zone to have ID **/
data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}
/** Create a cloudfront distribution **/
resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name              = module.s3_bucket.s3_bucket_bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id                = "S3-${module.s3_bucket.s3_bucket_id}"
  }
  aliases     = ["ailves2009.com", "*.ailves2009.com"]
  price_class = "PriceClass_100"

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project} distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "S3-${module.s3_bucket.s3_bucket_id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD", "OPTIONS"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = "${aws_lambda_function.cfle.arn}:${aws_lambda_function.cfle.version}"
      include_body = false #тело запроса не будет передано в функцию Lambda
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    // cloudfront_default_certificate = true
    acm_certificate_arn      = data.aws_acm_certificate.wildcard.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  tags = {
    Name = "${var.project_long}-${var.environment}"
  }
}
output "cloudfront_etag" {
  description = "The current version of the CloudFront Distribution"
  value       = aws_cloudfront_distribution.this.etag
}
output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront Distribution"
  value       = aws_cloudfront_distribution.this.domain_name
}

/** Create a route53 record for CV page on cloudfront distribution **/
resource "aws_route53_record" "cv" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "cv.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
/** Create a route53 record for root page on cloudfront distribution **/
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
/***
 * DynamoDB Table for the page-view counter.
 *
 * Было: PROVISIONED 20 RCU / 20 WCU + GSI на 10/10 = 30/30 при free tier
 * 25/25, что давало $3.48/мес на таблице из 45 записей общим объёмом 993 байта.
 * GSI "ViewsIndex" не читался ни из одной Lambda.
 *
 * Стало: PAY_PER_REQUEST. При текущем трафике это ~$0.00 и нет риска
 * троттлинга на всплеске.
 ***/
resource "aws_dynamodb_table" "this" {
  name         = "${var.project}_pagecounter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name = "dynamodb-pagecounter"
  }
}
