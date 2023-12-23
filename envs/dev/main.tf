resource "aws_s3_bucket" "this" {
  bucket = "${var.solution}-${var.project}-${var.environment}"
  lifecycle {
    prevent_destroy = false
  }
  tags = {
    Name = "${var.solution}-${var.project}-${var.environment}"
  }
}
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
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
      "Resource": "${aws_s3_bucket.this.arn}/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "arn:aws:cloudfront::${var.aws_account}:distribution/${aws_cloudfront_distribution.this.id}"
        }
      }
    }
  ]
}
EOF
  lifecycle {
    prevent_destroy = false
  }
}
/**** Cloud Front Distribution, that only access s3 bucket ****/
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.project}_oai"
  description                       = "${var.project}_policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  origin {
    domain_name = aws_s3_bucket.this.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
    origin_id   = "S3-${aws_s3_bucket.this.bucket}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project} distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id = "S3-${aws_s3_bucket.this.bucket}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
    viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = {
    Name = "${var.solution}-${var.project}-${var.environment}"
  }
}

