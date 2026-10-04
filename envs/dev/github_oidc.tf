/**
 * GitHub Actions access to AWS via OIDC.
 *
 * Replaces the static IAM user credentials kept in repository secrets: key
 * AKIARYXW3M6OW75KA6N6 for user github-actions was issued on 2022-02-12 and
 * has never been rotated. OIDC hands out temporary credentials scoped to a
 * single job — nothing to leak and nothing to rotate.
 *
 * ROLLOUT ORDER:
 *   1. terraform apply in envs/dev — creates the provider and the role
 *   2. take the github_actions_role_arn output and store it in
 *      GitHub -> Settings -> Secrets and variables -> Actions -> Variables
 *      as AWS_ROLE_ARN
 *   3. merge the updated .github/workflows/main.yml
 *   4. revoke the github-actions user key:
 *        aws iam delete-access-key --user-name github-actions \
 *          --access-key-id AKIARYXW3M6OW75KA6N6
 *      and remove the AWS_ACCESS_KEY / AWS_SECRET_KEY repository secrets
 *
 * IAM is free, so this file has no effect on the bill.
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

    # Without this condition ANY repository on GitHub could assume the role.
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
  # Exactly what the pipeline needs: sync the site into the bucket.
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

  # ... and invalidate CloudFront, otherwise changes take up to a day to show.
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
