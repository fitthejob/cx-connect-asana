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
        "repo:fitthejob/cx-connect-asana:ref:refs/heads/main",
        "repo:fitthejob@210087960/cx-connect-asana@1350889274:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "cx-connect-asana-deploy-role"
  description        = "GitHub Actions OIDC deploy role for cx-connect-asana CI"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

data "aws_iam_policy_document" "pr_checks_trust" {
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
        "repo:fitthejob/cx-connect-asana:pull_request",
        "repo:fitthejob@210087960/cx-connect-asana@1350889274:pull_request"
      ]
    }
  }
}

resource "aws_iam_role" "pr_checks" {
  name               = "cx-connect-asana-pr-checks-role"
  description        = "GitHub Actions OIDC read-only role for cx-connect-asana PR checks (terraform plan/validate, security scans)"
  assume_role_policy = data.aws_iam_policy_document.pr_checks_trust.json
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
      "lambda:AddPermission",
      "lambda:RemovePermission",
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-ticket-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-ticket-*:*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-recording-transcribe-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-recording-transcribe-*:*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-transcript-update-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-transcript-update-*:*",
    ]
  }

  statement {
    sid       = "LambdaLayerRead"
    effect    = "Allow"
    actions   = ["lambda:GetLayerVersion"]
    resources = ["*"]
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
      "connect:AssociateLambdaFunction",
      "connect:DisassociateLambdaFunction",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IamAsanaLambdaResourceManage"
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
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda-asana-*-${var.environment}",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lambda-asana-*-${var.environment}",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/asana-lex-speech-detection-role-${var.environment}",
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
      "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:lambda-asana-*",
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
      "secretsmanager:GetResourcePolicy",
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
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
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
    resources = [
      "arn:aws:s3:::${var.connect_terraform_tfstate_bucket}/connect/dev/terraform.tfstate",
      "arn:aws:s3:::${var.connect_terraform_tfstate_bucket}",
    ]
  }

  statement {
    sid    = "DynamoDbTableManage"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:UpdateTable",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:ListTagsOfResource",
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/contact-correlation-*",
    ]
  }

  statement {
    sid    = "RecordingBucketNotificationManage"
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification",
      "s3:PutBucketNotification",
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:aws:s3:::${var.recording_bucket_name}",
      "arn:aws:s3:::${var.recording_bucket_name}/*",
    ]
  }

  statement {
    sid       = "TranscribeManage"
    effect    = "Allow"
    actions   = ["transcribe:StartTranscriptionJob"]
    resources = ["*"]
  }

  statement {
    sid    = "EventBridgeManage"
    effect = "Allow"
    actions = [
      "events:DescribeRule",
      "events:PutRule",
      "events:DeleteRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:ListTargetsByRule",
      "events:TagResource",
      "events:UntagResource",
      "events:ListTagsForResource",
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:rule/lambda-asana-*",
    ]
  }

  statement {
    sid    = "CloudWatchAlarmManage"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "cloudwatch:ListTagsForResource",
    ]
    resources = [
      "arn:aws:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:lambda-asana-*",
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

# Split out from deploy_permissions above because the combined document
# exceeded IAM's 6144-char policy size limit -- same split connect-terraform
# uses for its own oversized deploy policy (see modules/iam/main.tf's
# aws_iam_policy.contact_center).
data "aws_iam_policy_document" "deploy_permissions_lex" {
  statement {
    sid    = "LexV2Manage"
    effect = "Allow"
    actions = [
      "lex:DescribeBot",
      "lex:CreateBot",
      "lex:UpdateBot",
      "lex:DeleteBot",
      "lex:ListBots",
      "lex:TagResource",
      "lex:UntagResource",
      "lex:ListTagsForResource",
      "lex:DescribeBotLocale",
      "lex:CreateBotLocale",
      "lex:UpdateBotLocale",
      "lex:DeleteBotLocale",
      "lex:ListBotLocales",
      "lex:BuildBotLocale",
      "lex:DescribeIntent",
      "lex:CreateIntent",
      "lex:UpdateIntent",
      "lex:DeleteIntent",
      "lex:ListIntents",
      "lex:DescribeBotVersion",
      "lex:CreateBotVersion",
      "lex:DeleteBotVersion",
      "lex:ListBotVersions",
      "lex:CreateBotAlias",
      "lex:UpdateBotAlias",
      "lex:DeleteBotAlias",
      "lex:DescribeBotAlias",
      "lex:ListBotAliases",
    ]
    # lex:CreateBot's target doesn't exist before the call (the bot ID is
    # assigned by AWS on creation), so this can't be scoped ahead of a first
    # apply -- same justification connect-terraform uses for its own
    # LexV2Manage statement.
    resources = ["*"]
  }

  statement {
    sid    = "ConnectBotAssociation"
    effect = "Allow"
    actions = [
      "connect:AssociateBot",
      "connect:DisassociateBot",
      "connect:ListBots",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy_lex" {
  name   = "cx-connect-asana-deploy-lex-policy"
  policy = data.aws_iam_policy_document.deploy_permissions_lex.json
}

resource "aws_iam_role_policy_attachment" "deploy_lex" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy_lex.arn
}

data "aws_iam_policy_document" "pr_checks_permissions" {
  statement {
    sid    = "LambdaFunctionReadOnly"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetFunctionEventInvokeConfig",
      "lambda:GetAlias",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:GetPolicy",
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-ticket-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-ticket-*:*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-recording-transcribe-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-recording-transcribe-*:*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-transcript-update-*",
      "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:asana-transcript-update-*:*",
    ]
  }

  statement {
    sid    = "ConnectReadOnly"
    effect = "Allow"
    actions = [
      "connect:Describe*",
      "connect:Get*",
      "connect:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IamReadOnly"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda-asana-*-${var.environment}",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/lambda-asana-*-${var.environment}",
    ]
  }

  statement {
    sid    = "SqsReadOnly"
    effect = "Allow"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueueTags",
    ]
    resources = [
      "arn:aws:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:lambda-asana-ticket-*",
    ]
  }

  statement {
    sid    = "SecretsManagerReadOnly"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:asana-api-token-*",
    ]
  }

  statement {
    sid       = "LambdaKmsKeyReadOnly"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/*"]
  }

  statement {
    sid    = "StateBucketAccess"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
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
    resources = [
      "arn:aws:s3:::${var.connect_terraform_tfstate_bucket}/connect/dev/terraform.tfstate",
      "arn:aws:s3:::${var.connect_terraform_tfstate_bucket}",
    ]
  }

  statement {
    sid    = "DynamoDbTableReadOnly"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:ListTagsOfResource",
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:table/contact-correlation-*",
    ]
  }

  statement {
    sid    = "RecordingBucketReadOnly"
    effect = "Allow"
    actions = [
      "s3:GetBucketNotification",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.recording_bucket_name}",
    ]
  }

  statement {
    sid    = "EventBridgeReadOnly"
    effect = "Allow"
    actions = [
      "events:DescribeRule",
      "events:ListTargetsByRule",
      "events:ListTagsForResource",
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:rule/lambda-asana-*",
    ]
  }

  statement {
    sid       = "CloudWatchAlarmReadOnly"
    effect    = "Allow"
    actions   = ["cloudwatch:DescribeAlarms"]
    resources = ["*"]
  }

  statement {
    sid       = "CloudWatchAlarmTagsReadOnly"
    effect    = "Allow"
    actions   = ["cloudwatch:ListTagsForResource"]
    resources = ["arn:aws:cloudwatch:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:alarm:lambda-asana-*"]
  }

  statement {
    sid    = "LexV2ReadOnly"
    effect = "Allow"
    actions = [
      "lex:DescribeBot",
      "lex:ListBots",
      "lex:DescribeBotLocale",
      "lex:ListBotLocales",
      "lex:DescribeIntent",
      "lex:ListIntents",
      "lex:DescribeBotVersion",
      "lex:ListBotVersions",
      "lex:DescribeBotAlias",
      "lex:ListBotAliases",
      "lex:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ConnectBotAssociationReadOnly"
    effect = "Allow"
    actions = [
      "connect:ListBots",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "CallerIdentityForArnConstruction"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "pr_checks" {
  name   = "cx-connect-asana-pr-checks-policy"
  policy = data.aws_iam_policy_document.pr_checks_permissions.json
}

resource "aws_iam_role_policy_attachment" "pr_checks" {
  role       = aws_iam_role.pr_checks.name
  policy_arn = aws_iam_policy.pr_checks.arn
}

output "deploy_role_arn" {
  value = aws_iam_role.deploy.arn
}

output "pr_checks_role_arn" {
  value = aws_iam_role.pr_checks.arn
}
