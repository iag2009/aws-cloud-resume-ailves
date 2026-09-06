locals {
  dynamodb_table_name = aws_dynamodb_table.this.name

  # Домены, которым разрешено дёргать Function URL из браузера.
  counter_allowed_origins = [
    "https://${var.domain_name}",
    "https://cv.${var.domain_name}",
  ]
}

################################################################################
# Read-only счётчик за Lambda Function URL (регион var.aws_region)
################################################################################

## Имя таблицы и её регион подставляются из Terraform, а не хардкодятся
## в Python: раньше переименование var.project молча ломало обе функции.
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
  runtime          = "python3.13" # python3.8 снят с поддержки, AWS блокирует обновление таких функций
  memory_size      = 128
  timeout          = 5
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = 14
}

## Публичный URL функции. Авторизации нет намеренно — эндпоинт read-only и
## отдаёт число, которое и так видно на странице.
resource "aws_lambda_function_url" "this" {
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"

  cors {
    # allow_credentials = true вместе с allow_origins = ["*"] браузер
    # отвергает, а куки этому эндпоинту не нужны.
    allow_credentials = false
    allow_origins     = local.counter_allowed_origins
    allow_methods     = ["GET"]
    # Раньше здесь были "date" и "keep-alive" — это forbidden headers,
    # JS их выставить не может, а простой GET дополнительных заголовков
    # не шлёт, поэтому allow_headers не задаём вовсе.
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
          # edgelambda.amazonaws.com обязателен для Lambda@Edge
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
        # Lambda@Edge пишет логи в регион ближайшей точки присутствия,
        # поэтому регион здесь не сужаем.
        Resource = [
          "arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
          "arn:${data.aws_partition.current.partition}:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:log-stream:*",
        ]
      },
      {
        Effect = "Allow"
        # PutItem убран: счётчик инкрементится атомарным UpdateItem.
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
# Lambda@Edge — инкремент счётчика (обязан жить в us-east-1)
################################################################################

data "archive_file" "zip_the_python_code_cfle" {
  type        = "zip"
  output_path = "${path.module}/lambda/func-cfle.zip"

  source {
    filename = "func-cfle.py"
    content = templatefile("${path.module}/lambda/func-cfle.py.tftpl", {
      table_name   = local.dynamodb_table_name
      table_region = var.aws_region
    })
  }
}

resource "aws_lambda_function" "cfle" {
  provider         = aws.us-east-1
  filename         = data.archive_file.zip_the_python_code_cfle.output_path
  source_code_hash = data.archive_file.zip_the_python_code_cfle.output_base64sha256
  function_name    = "update_dynamodb_counter_cfle"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "func-cfle.handler"
  runtime          = "python3.13"
  memory_size      = 128
  # Вызов DynamoDB кросс-регионально; в коде таймауты жёстче этого значения.
  timeout = 5
  # Lambda@Edge принимает только пронумерованную версию, не $LATEST.
  publish = true
}

resource "aws_lambda_permission" "cfle" {
  provider      = aws.us-east-1
  statement_id  = "AllowExecutionFromCloudFront"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cfle.function_name
  principal     = "edgelambda.amazonaws.com"
  qualifier     = aws_lambda_function.cfle.version
}

## Log group для Lambda@Edge здесь намеренно НЕ создаётся.
##
## Раньше тут был aws_cloudwatch_log_group с именем
## /aws/lambda/update_dynamodb_counter_cfle и retention 14 дней. Эта группа
## всегда оставалась пустой: Lambda@Edge пишет в /aws/lambda/us-east-1.<имя>
## в каждом edge-регионе, где выполнялась функция. Terraform не может знать
## этот список заранее, поэтому retention проставляется скриптом
## scripts/stage0-cleanup-orphans.sh (раздел 4).
