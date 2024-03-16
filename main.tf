data "aws_caller_identity" "current" {
}

data "aws_partition" "current" {
}

module "tags" {
  source  = "rhythmictech/tags/terraform"
  version = "~> 1.1.1"

  enforce_case = "UPPER"
  names        = ["Rhythmic-AccountMonitoring"]
  tags = merge(var.tags, {
    "team"    = "Rhythmic"
    "service" = "aws_managed_services"
  })
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  tags       = module.tags.tags_no_name
}

resource "aws_kms_key" "this" {
  description             = "KMS key for encrypting notifications to Rhythmic"
  enable_key_rotation     = false #tfsec:ignore:avd-aws-0065
  deletion_window_in_days = 10
  policy                  = data.aws_iam_policy_document.this.json
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/rhythmic-notifications"
  target_key_id = aws_kms_key.this.key_id
}

data "aws_iam_policy_document" "this" {
  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "budgets.amazonaws.com",
        "costalerts.amazonaws.com",
        "events.amazonaws.com"
      ]
    }
  }
}
