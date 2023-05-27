#IAM POLICIES
data "aws_iam_policy_document" "kms-admin" {
  statement {
    sid       = "AllowAllKMS"
    effect    = "Allow"
    resources = [" arn:aws:kms:*:111122223333:key/*"]
    actions   = ["kms:*"]
  }

  statement {
    sid       = "DenyKMSKeyUsage"
    effect    = "Deny"
    resources = [" arn:aws:kms:*:111122223333:key/*"]

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
    ]
  }
}


data "aws_iam_policy_document" "authorized-access" {
  statement {
    sid       = "BasicList"
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "s3:ListAllMyBuckets",
      "s3:HeadBucket",
    ]
  }

  statement {
    sid    = "AllowSecureBucket"
    effect = "Allow"

    resources = [
      "arn:aws:s3:::drive-cloud/*",
      "arn:aws:s3:::drive-cloud",
    ]

    actions = [
      "s3:PutObject",
      "s3:GetObjectAcl",
      "s3:GetObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteObject",
      "s3:GetBucketLocation",
      "s3:GetObjectVersion",
    ]
  }
}

data "aws_iam_policy_document" "bucket-admin" {
  statement {
    sid       = "AllowAllActions"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["s3:*"]
  }

  statement {
    sid       = "DenyObjectAccess"
    effect    = "Deny"
    resources = ["arn:aws:s3:::drive-cloud"]

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:PutObjectVersionAcl",
    ]
  }
}

# IAM POLICIES
resource "aws_iam_policy" "bucket-admin" {
  name   = "secure-bucket-admin"
  path   = "/"
  policy = data.aws_iam_policy_document.bucket-admin.json 
}   

resource "aws_iam_policy" "authorized-access" {
  name   = "secure-bucket-access"
  path   = "/"
  policy = data.aws_iam_policy_document.authorized-access.json
}

resource "aws_iam_policy" "kms-admin" {
  name   = "kms-admin"
  path   = "/"
  policy = data.aws_iam_policy_document.kms-admin.json
}
