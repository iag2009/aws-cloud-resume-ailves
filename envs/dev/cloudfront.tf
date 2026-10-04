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
/** AWS-managed cache policy: TTLs from Cache-Control, gzip + brotli keys **/
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

locals {
  /**
   * Every origin the page loads from. Third-party styles in index.html carry
   * SRI hashes; a new CDN there needs a matching entry here, otherwise the
   * browser refuses it. There are no third-party scripts at all.
   * typed.js is configured with autoInsertCss = false, so no inline styles.
   **/
  content_security_policy = join("; ", [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' https://cdn.jsdelivr.net https://cdnjs.cloudflare.com https://fonts.googleapis.com",
    "font-src 'self' https://cdnjs.cloudflare.com https://fonts.gstatic.com",
    "img-src 'self' data:",
    "connect-src 'self' ${trimsuffix(aws_lambda_function_url.this.function_url, "/")}",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'none'",
    "frame-ancestors 'none'",
  ])
}

/** Security headers on every response **/
resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.project}-security-headers"
  comment = "HSTS, CSP, nosniff, frame and referrer policy for ${var.domain_name}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      # Deliberately no includeSubDomains/preload: they would bind every
      # current and future subdomain of the zone to HTTPS for a year.
      include_subdomains = false
      preload            = false
      override           = true
    }
    content_security_policy {
      content_security_policy = local.content_security_policy
      override                = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
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

  /**
   * Was: legacy forwarded_values with a 3600 s default TTL, compression off
   * (HTML went out uncompressed, 17.8 KB) and a Lambda@Edge viewer-request
   * trigger on every request just to count views. The counter now lives
   * behind the Function URL (lambda.tf), so there is no edge function.
   *
   * CachingOptimized caches for a day by default; that is fine because the
   * deploy workflow invalidates /* after every sync.
   **/
  default_cache_behavior {
    target_origin_id       = "S3-${module.s3_bucket.s3_bucket_id}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  /**
   * With OAC and no s3:ListBucket, S3 answers 403 for a missing key, and
   * visitors used to see the raw <Error><Code>AccessDenied</Code> XML.
   * Both codes now return website/404.html with an honest 404.
   **/
  custom_error_response {
    error_code            = 403
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
  }
  custom_error_response {
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
    error_caching_min_ttl = 300
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
 * DynamoDB table for the page-view counter.
 *
 * Was: PROVISIONED 20 RCU / 20 WCU plus a GSI at 10/10, i.e. 30/30 against a
 * free tier of 25/25. That cost $3.48/month for a table holding 45 items
 * totalling 993 bytes, and no Lambda ever read the "ViewsIndex" GSI.
 *
 * Now: PAY_PER_REQUEST. At current traffic that is ~$0.00, and a traffic
 * spike can no longer be throttled.
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
