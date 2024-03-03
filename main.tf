data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
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
  region     = data.aws_region.current.name
  tags       = module.tags.tags_no_name
}

resource "aws_kms_key" "this" {
  description             = "KMS key for encrypting notifications to Rhythmic"
  enable_key_rotation     = false
  deletion_window_in_days = 10
  policy                  = data.aws_iam_policy_document.this.json
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
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDateKey*",
      "kms:Decrypt"
    ]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "budgets.amazonaws.com",
        "costalerts.amazonaws.com"
      ]
    }
  }
}
