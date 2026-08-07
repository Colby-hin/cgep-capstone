data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Project         = "cgep-capstone"
    Environment     = "capstone"
    ManagedBy       = "Terraform"
    ComplianceScope = "HIPAA"
  }
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1

  url = "https://token.actions.githubusercontent.com"
}

locals {
  github_oidc_provider_arn = var.create_oidc_provider ? (
    aws_iam_openid_connect_provider.github[0].arn
    ) : (
    data.aws_iam_openid_connect_provider.github[0].arn
  )

  github_repository_immutable = "repo:${split("/", var.github_repository)[0]}@${var.github_owner_id}/${split("/", var.github_repository)[1]}@${var.github_repository_id}"

  plan_subjects = [
    "repo:${var.github_repository}:pull_request",
    "${local.github_repository_immutable}:pull_request",
    "repo:${var.github_repository}:ref:refs/heads/main",
    "${local.github_repository_immutable}:ref:refs/heads/main",
    "repo:${var.github_repository}:ref:refs/heads/capstone-foundation",
    "${local.github_repository_immutable}:ref:refs/heads/capstone-foundation"
  ]

  deploy_subjects = [
    "repo:${var.github_repository}:ref:refs/heads/main",
    "${local.github_repository_immutable}:ref:refs/heads/main",
    "repo:${var.github_repository}:ref:refs/heads/capstone-foundation",
    "${local.github_repository_immutable}:ref:refs/heads/capstone-foundation"
  ]

  state_key      = "cgep-capstone/terraform.tfstate"
  state_lock_key = "cgep-capstone/terraform.tfstate.tflock"
}

############################################################
# Plan role trust policy
############################################################

data "aws_iam_policy_document" "plan_trust" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        local.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_subjects
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "cgep-capstone-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600

  tags = {
    Project         = "cgep-capstone"
    Environment     = "capstone"
    ManagedBy       = "Terraform"
    ComplianceScope = "HIPAA"
    Purpose         = "github-plan"
  }
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "github_plan_state" {
  statement {
    sid = "ListTerraformStateBucket"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket_name}"
    ]
  }

  statement {
    sid = "ReadTerraformState"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket_name}/${local.state_key}"
    ]
  }

  statement {
    sid = "ManageTerraformStateLock"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket_name}/${local.state_lock_key}"
    ]
  }
}

resource "aws_iam_role_policy" "github_plan_state" {
  name   = "terraform-state-and-lock"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_state.json
}

############################################################
# Deploy role trust policy
############################################################

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        local.github_oidc_provider_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.deploy_subjects
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name                 = "cgep-capstone-github-deploy"
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600

  tags = {
    Project         = "cgep-capstone"
    Environment     = "capstone"
    ManagedBy       = "Terraform"
    ComplianceScope = "HIPAA"
    Purpose         = "github-deploy"
  }
}

# This is intentionally limited to the course sandbox. The additional
# inline policy restricts IAM administration to cgep-* application roles.
resource "aws_iam_role_policy_attachment" "github_deploy_power_user" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "github_deploy_additional" {
  statement {
    sid = "ListTerraformStateBucket"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket_name}"
    ]
  }

  statement {
    sid = "ManageTerraformStateAndLock"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket_name}/${local.state_key}"
    ]
  }

  statement {
    sid = "ManageTerraformLockFile"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]

    resources = [
      "arn:aws:s3:::${var.state_bucket_name}/${local.state_lock_key}"
    ]
  }

  statement {
    sid = "UseEvidenceVault"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketVersioning",
      "s3:GetBucketEncryption",
      "s3:GetBucketObjectLockConfiguration"
    ]

    resources = [
      "arn:aws:s3:::${var.evidence_bucket_name}"
    ]
  }

  statement {
    sid = "WriteAndVerifyEvidence"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectRetention",
      "s3:GetObjectAttributes"
    ]

    resources = [
      "arn:aws:s3:::${var.evidence_bucket_name}/*"
    ]
  }

  statement {
    sid = "UseCapstoneKMSKey"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = [
      var.capstone_kms_key_arn
    ]
  }

  statement {
    sid = "ManageCapstoneIAMRoles"

    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cgep-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/acme-health-intake-lambda-*"
    ]
  }

  statement {
    sid = "ReadLambdaVPCManagedPolicy"

    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion"
    ]

    resources = [
      "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    ]
  }
}

resource "aws_iam_role_policy" "github_deploy_additional" {
  name   = "capstone-deployment-additional"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy_additional.json
}
