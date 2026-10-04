locals {
  dynamodb_table_name = aws_dynamodb_table.this.name

  # Origins allowed to call the Function URL from a browser.
  counter_allowed_origins = [
    "https://${var.domain_name}",
    "https://cv.${var.domain_name}",
  ]
}

################################################################################
# View counter behind a Lambda Function URL (in var.aws_region)
#
# GET returns the count, POST increments it and returns the new value. The page
# POSTs once per browser session (website/index.js).
################################################################################

## The table name and region are injected by Terraform rather than hardcoded
## in Python: renaming var.project used to break both functions silently.
data "archive_file" "zip_the_python_code" {
  type        = "zip"
  output_path = "${path.module}/lambda/func.zip"

  source {
    filename = "func.py"
    content = templatefile("${path.module}/lambda/func.py.tftpl", {
      table_name   = local.dynamodb_table_name
      table_region = var.aws_region
    })
  }
}

resource "aws_lambda_function" "this" {
  filename         = data.archive_file.zip_the_python_code.output_path
  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha256
  function_name    = "update_dynamodb_counter"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.handler"
  runtime          = "python3.13" # python3.8 is deprecated; AWS blocks updates to such functions
  memory_size      = 128
  timeout          = 5

  # The URL is public and POST writes to DynamoDB. Two concurrent executions
  # (~40 req/s at this function's latency) are plenty for a CV page and cap
  # what a script hammering the URL can cost. Excess requests get HTTP 429.
  reserved_concurrent_executions = 2
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}

## Public function URL. Authorization is intentionally absent: the endpoint only
## reads and bumps a vanity counter, and reserved concurrency caps abuse.
resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"

  cors {
    # Browsers reject allow_credentials = true combined with
    # allow_origins = ["*"], and this endpoint has no use for cookies.
    allow_credentials = false
    allow_origins     = local.counter_allowed_origins
    allow_methods     = ["GET", "POST"]
    # This used to list "date" and "keep-alive", which are forbidden headers
    # that JavaScript cannot set. A body-less GET or POST without custom
    # headers is a CORS "simple request", so allow_headers is omitted.
    max_age = 86400
  }
}

################################################################################
# IAM
################################################################################

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          # edgelambda.amazonaws.com is required for Lambda@Edge
          # TODO(stage 4b): drop edgelambda once the old Lambda@Edge function is
          # deleted. Its replicas may still run with this role until CloudFront
          # finishes deploying the distribution without the trigger.
          Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        }
      },
    ]
  })
}

resource "aws_iam_policy" "iam_policy_for_resume_project" {
  name        = "aws_iam_policy_for_terraform_resume_project_policy"
  path        = "/"
  description = "AWS IAM Policy for managing the resume project role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        # Lambda@Edge writes logs in the region of the nearest edge location,
        # so the region is left as a wildcard.
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
          "arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:log-stream:*",
        ]
      },
      {
        Effect = "Allow"
        # PutItem is gone: the counter is incremented with an atomic UpdateItem.
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
        ]
        Resource = aws_dynamodb_table.this.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_resume_project.arn
}

################################################################################
# Former Lambda@Edge counter (update_dynamodb_counter_cfle, us-east-1)
#
# It ran on EVERY viewer request — every asset, every cache hit — to bump the
# counter, on python3.8. The increment moved into the Function URL above.
#
# Terraform cannot delete it in the same apply that detaches it from
# CloudFront: Lambda refuses to delete a function until its edge replicas are
# gone, which takes from minutes to a few hours. So the function is only
# forgotten here, and scripts/stage4-remove-lambda-edge.sh deletes it (with all
# versions and per-region log groups) afterwards.
################################################################################

removed {
  from = aws_lambda_function.cfle
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_lambda_permission.cfle
  lifecycle {
    destroy = false
  }
}
