/*
locals {
  name                      = "ecr-${var.project}-${replace(basename(path.cwd), "_", "-")}"
  create_private_repository = var.ecr_create && var.ecr_create_repository && var.ecr_repository_type == "private"
  create_public_repository  = var.ecr_create && var.ecr_create_repository && var.ecr_repository_type == "public"

  tags = {
    Name       = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecr"
  }
}

################################################################################
# ECR Repositories
################################################################################

module "private_ecr" {
  #  ссылка на мой модуль, который я выложил в репозиторий terraform-aws-modules/ailves_aws_ecr
  # source = "../modules/ailves_aws_ecr"
  # providers = {
  #   aws.instancemaker = aws.us-east-1
  # }

  source = "terraform-aws-modules/ecr/aws"

  repository_name        = local.name
  repository_type        = "private"
  create                 = var.ecr_create
  create_repository      = var.ecr_create_repository
  # create_registry_policy = var.ecr_create_registry_policy

  repository_read_write_access_arns = concat([data.aws_caller_identity.current.arn], var.ecr_repository_read_write_access_arns)
  repository_read_access_arns       = var.ecr_repository_read_access_arns
  create_lifecycle_policy           = true
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  repository_force_delete = true

  tags = local.tags
}

module "public_ecr" {
  #  ссылка на мой модуль, который я выложил в репозиторий terraform-aws-modules/ailves_aws_ecr
  # source = "../modules/ailves_aws_ecr"
  # providers = {
  #   aws.instancemaker = aws.us-east-1
  # }
  source = "terraform-aws-modules/ecr/aws"

  #create                 = var.ecr_create
  #create_repository      = var.ecr_create_repository
  #create_registry_policy = var.ecr_create_registry_policy
  repository_name        = local.name
  repository_type        = "public"

  repository_read_write_access_arns = concat([data.aws_caller_identity.current.arn], var.ecr_repository_read_write_access_arns)
  repository_read_access_arns       = ["*"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 30 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 30
        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  public_repository_catalog_data = {
    description       = "Docker container for some things"
    about_text        = file("${path.module}/ecr-files/ABOUT.md")
    usage_text        = file("${path.module}/ecr-files/USAGE.md")
    operating_systems = ["Linux"]
    architectures     = ["x86"]
    logo_image_blob   = filebase64("${path.module}/ecr-files/clowd.png") //toDo - не отображается image
  }

  tags = local.tags
}

################################################################################
# ECR Registry
################################################################################

data "aws_iam_policy_document" "registry" {
  # count = local.create_private_repository ? 1 : 0
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "ecr:ReplicateImage",
    ]

    resources = [
      module.private_ecr.repository_arn,
    ]
  }
}

module "ecr_registry" {
  #  ссылка на мой модуль, который я выложил в репозиторий terraform-aws-modules/ailves_aws_ecr
  # source = "../modules/ailves_aws_ecr"
  # providers = {
  #   aws.instancemaker = aws.us-east-1
  # }
  #count             = local.create_private_repository ? 1 : 0
  source            = "terraform-aws-modules/ecr/aws"
  create            = var.ecr_create
  create_repository = var.ecr_create_repository

  # Registry Policy
  create_registry_policy = true
  registry_policy        = data.aws_iam_policy_document.registry.json

  # Registry Pull Through Cache Rules
  registry_pull_through_cache_rules = {
    pub = {
      ecr_repository_prefix = "ecr-public_prefix" // images с таким префиксом будут грузиться из upstream_registry_url
      upstream_registry_url = "public.ecr.aws"
    }
  }

  # Registry Scanning Configuration
  manage_registry_scanning_configuration = true
  registry_scan_type                     = "ENHANCED"
  registry_scan_rules = [
    {
      scan_frequency = "SCAN_ON_PUSH"
      filter         = "*"
      filter_type    = "WILDCARD"
      }, {
      scan_frequency = "CONTINUOUS_SCAN"
      filter         = "example"
      filter_type    = "WILDCARD"
    }
  ]

  # Registry Replication Configuration
  create_registry_replication_configuration = true
  registry_replication_rules = [
    {
      destinations = [{
        region      = "us-west-2"
        registry_id = data.aws_caller_identity.current.account_id
        }, {
        region      = "eu-west-1"
        registry_id = data.aws_caller_identity.current.account_id
      }]

      repository_filters = [{
        filter      = "prod-microservice"
        filter_type = "PREFIX_MATCH"
      }]
    }
  ]

  tags = local.tags
}
*/