data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:fitthejob/cx-connect-asana:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "cx-connect-asana-deploy-role"
  description        = "GitHub Actions OIDC deploy role for cx-connect-asana CI"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "deploy_permissions" {
  statement {
    sid    = "LambdaFunctionManage"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetAlias",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:DeleteFunction",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:DeleteAlias",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:GetFunctionEventInvokeConfig",
      "lambda:PutFunctionEventInvokeConfig",
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-ticket-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-ticket-*:*",
    ]
  }

  statement {
    sid    = "ConnectFlowModuleManage"
    effect = "Allow"
    actions = [
      "connect:Describe*",
      "connect:Get*",
      "connect:List*",
      "connect:CreateContactFlowModule",
      "connect:UpdateContactFlowModule*",
      "connect:DeleteContactFlowModule",
      "connect:TagResource",
      "connect:UntagResource",
    ]
    # Not scoped to the specific Connect instance ARN -- this role has no
    # input for the instance ID (it's only known via connect-terraform's
    # remote state, not a resource this role owns), same deferred scoping
    # gap connect-terraform's own modules/iam leaves for ConnectManage.
    resources = ["*"]
  }

  statement {
    sid    = "IamScopedToThisLambda"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda-asana-ticket-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lambda-asana-ticket-*",
    ]
  }

  statement {
    sid    = "SqsDlqManage"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:CreateQueue",
      "sqs:SetQueueAttributes",
      "sqs:DeleteQueue",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:ListQueueTags",
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:lambda-asana-ticket-*",
    ]
  }

  statement {
    sid    = "SecretsManagerManage"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:asana-api-token-*",
    ]
  }

  statement {
    sid       = "LambdaKmsKeyRead"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  }

  statement {
    sid    = "IamAwsManagedPolicyAttach"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
    ]
    resources = [
      "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
      "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
    ]
  }

  statement {
    sid    = "LambdaArtifactsBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.lambda_artifacts_bucket}",
      "arn:aws:s3:::${var.lambda_artifacts_bucket}/*",
    ]
  }

  statement {
    sid    = "StateBucketAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.tfstate_bucket}",
      "arn:aws:s3:::${var.tfstate_bucket}/*",
    ]
  }

  statement {
    sid    = "ConnectTerraformStateReadOnly"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    # This repo's own data.terraform_remote_state.connect-terraform reads
    # connect/dev/terraform.tfstate for connect_instance_id and
    # shared_deps_layer_arn -- scoped to that one object, read-only, same
    # as connect-terraform's own load_test role scopes to a single dev
    # state object rather than the whole tfstate bucket.
    resources = [
      "arn:aws:s3:::${var.connect_terraform_tfstate_bucket}/connect/dev/terraform.tfstate",
      "arn:aws:s3:::${var.connect_terraform_tfstate_bucket}",
    ]
  }

  statement {
    sid       = "CallerIdentityForArnConstruction"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name   = "cx-connect-asana-deploy-policy"
  policy = data.aws_iam_policy_document.deploy_permissions.json
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}
