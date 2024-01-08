provider "aws" {
  alias  = "central"
  region = var.replication_aws_region
}

resource "aws_s3_bucket" "source" {
  // provider = aws.central
  bucket = "${var.bucket_name}-source"
  tags          = "${var.tags}"
  force_destroy = "${var.force_destroy}"
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.source.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "${var.s3_policy_service}"
      },
      "Action": "s3:GetObject",
      "Resource": "${aws_s3_bucket.source.arn}/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceArn": "arn:aws:${var.s3_policy_condition_arn}"
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

/** Replication **/
/*
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "replication" {
  name               = "tf-iam-role-replication-12345"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket",
    ]

    resources = [aws_s3_bucket.source.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
    ]

    resources = ["${aws_s3_bucket.source.arn}/*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
    ]

    resources = ["${aws_s3_bucket.destination.arn}/*"]
  }
}

resource "aws_iam_policy" "replication" {
  name   = "tf-iam-role-policy-replication-12345"
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}
*/
resource "aws_s3_bucket" "destination" {
  bucket = "${var.bucket_name}-destination"
}

resource "aws_s3_bucket_versioning" "destination" {
  bucket = aws_s3_bucket.destination.id
  versioning_configuration {
    status = "Enabled"
  }
}
/*
resource "aws_s3_bucket_versioning" "source" {
  provider = aws.central

  bucket = aws_s3_bucket.source.id
  versioning_configuration {
    status = "Enabled"
  }
}
*/
/*
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.central
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.source]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.source.id

  rule {
    id = "foobar"

    filter {
      prefix = "foo"
    }
    delete_marker_replication {
        status = "Enabled"
    }
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD"
    }
  }
}
*/