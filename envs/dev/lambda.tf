## Lambda to update DynamoDB counter
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.zip_the_python_code.output_path
  source_code_hash = data.archive_file.zip_the_python_code.output_base64sha256
  function_name    = "update_dynamodb_counter"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func.handler"
  runtime          = "python3.8"
}
## Create CloudWatch Log group for Lambda in us-east-2
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/update_dynamodb_counter"
  retention_in_days = 14
}
## Archive Lambda source code
data "archive_file" "zip_the_python_code" {
  type        = "zip"
  source_file = "${path.module}/lambda/func.py"
  output_path = "${path.module}/lambda/func.zip"
}
## Create URL для функции AWS Lambda, который может быть использован для вызова функции без авторизации
resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
## Create IAM role for Lambda
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
## Attach IAM policy to IAM role
resource "aws_iam_policy" "iam_policy_for_resume_project" {

  name        = "aws_iam_policy_for_terraform_resume_project_policy"
  path        = "/"
  description = "AWS IAM Policy for managing the resume project role"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:*:*:*",
          "Effect" : "Allow"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:UpdateItem",
            "dynamodb:GetItem",
            "dynamodb:PutItem"
          ],
          "Resource" : "arn:aws:dynamodb:*:*:table/${var.project}_pagecounter"
        },
      ]
  })
}
        /*{
          "Effect": "Allow",
          "Action": "*",
          "Resource": "*"
        }
        */
 
resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_policy_for_resume_project.arn
}
## for Edge Location Lambda should be in us-east-1 region
resource "aws_lambda_function" "cfle" {
  provider         = aws.us-east-1
  filename         = data.archive_file.zip_the_python_code_cfle.output_path
  source_code_hash = data.archive_file.zip_the_python_code_cfle.output_base64sha256
  function_name    = "update_dynamodb_counter_cfle"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func-cfle.handler"
  runtime          = "python3.8"
  publish          = true
}

resource "aws_lambda_permission" "cfle" {
  provider      = aws.us-east-1
  statement_id  = "AllowExecutionFromCloudFront"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cfle.function_name
  principal     = "edgelambda.amazonaws.com"
  qualifier     = aws_lambda_function.cfle.version
}
## Archive Lambda source code
data "archive_file" "zip_the_python_code_cfle" {
  type        = "zip"
  source_file = "${path.module}/lambda/func-cfle.py"
  output_path = "${path.module}/lambda/func-cfle.zip"
}

resource "aws_cloudwatch_log_group" "cfle" {
  provider          = aws.us-east-1
  name              = "/aws/lambda/${aws_lambda_function.cfle.function_name}"
  retention_in_days = 14
}
