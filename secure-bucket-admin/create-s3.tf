data "aws_iam_policy_document" "s3-policy-kms" {
  statement {
    sid       = "DenyUnencryptedObjectUploads"
    effect    = "Deny"
    resources = ["arn:aws:s3:::drive-cloud/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  statement {
    sid       = "DenyWrongKMSKey"
    effect    = "Deny"
    resources = ["arn:aws:s3:::drive-cloud/*"]
    actions   = ["s3:PutObject"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = ["arn:aws:kms::11112222333:key/1234abcd-12ab-34cd-56ef-1234567890ab"]
    }

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket" "drive-cloud" {
  bucket = "drive-cloud"
  policy = data.aws_iam_policy_document.s3-policy-kms.json
}