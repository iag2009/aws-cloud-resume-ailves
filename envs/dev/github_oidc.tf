/**
 * Доступ GitHub Actions к AWS через OIDC.
 *
 * Заменяет статические ключи IAM-пользователя github-actions, лежащие в
 * секретах репозитория: ключ AKIARYXW3M6OW75KA6N6 выпущен 2022-02-12 и
 * ни разу не ротировался. OIDC выдаёт временные креденшелы на время job,
 * их нечего утекать и нечего ротировать.
 *
 * ПОРЯДОК ВНЕДРЕНИЯ:
 *   1. terraform apply в envs/dev  — создаст provider и роль
 *   2. взять из output github_actions_role_arn значение и положить его
 *      в GitHub → Settings → Secrets and variables → Actions → Variables
 *      как AWS_ROLE_ARN
 *   3. смёржить обновлённый .github/workflows/main.yml
 *   4. удалить ключ пользователя github-actions:
 *        aws iam delete-access-key --user-name github-actions \
 *          --access-key-id AKIARYXW3M6OW75KA6N6
 *      и секреты AWS_ACCESS_KEY / AWS_SECRET_KEY из репозитория
 *
 * IAM ничего не стоит, на счёт этот файл не влияет.
 */

variable "github_repository" {
  description = "GitHub repository allowed to assume the deployment role, as owner/name"
  type        = string
  default     = "iag2009/aws-cloud-resume-ailves"
}

variable "github_deploy_branches" {
  description = "Branches of var.github_repository allowed to assume the deployment role"
  type        = list(string)
  default     = ["master"]
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_actions_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Без этого условия роль сможет взять ЛЮБОЙ репозиторий на GitHub.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for b in var.github_deploy_branches : "repo:${var.github_repository}:ref:refs/heads/${b}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "github-actions-${var.project_long}"
  description        = "Deployment role assumed by GitHub Actions via OIDC"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume.json
}

data "aws_iam_policy_document" "github_actions_deploy" {
  # Ровно то, что нужно пайплайну: синхронизировать сайт в бакет.
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.s3_bucket.s3_bucket_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObject",
    ]
    resources = ["${module.s3_bucket.s3_bucket_arn}/*"]
  }

  # ... и сбросить кэш CloudFront, иначе изменения не видны до суток.
  statement {
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]
    resources = [aws_cloudfront_distribution.this.arn]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "deploy-website"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

output "github_actions_role_arn" {
  description = "Value for the AWS_ROLE_ARN repository variable in GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}
