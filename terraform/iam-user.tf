resource "aws_iam_user" "user_createKMSadmin" {
  name = "kms-admin"
  }


resource "aws_iam_user_policy_attachment" "kms-attach-policy" {
  user       = aws_iam_user.user_createKMSadmin.name
  policy_arn = aws_iam_policy.kms-admin.arn
}


resource "aws_iam_user" "user_create_bucket-admin" {
  name = "secure-bucket-admin-user"
  }


resource "aws_iam_user_policy_attachment" "admin-attach-policy" {
  user       = aws_iam_user.user_create_bucket-admin.name
  policy_arn = aws_iam_policy.bucket-admin.arn
}


resource "aws_iam_user" "bucket-access-user" {
  name = "bucket-access-user"
  }

resource "aws_iam_user_policy_attachment" "user-attach-policy" {
  user       = aws_iam_user.bucket-access-user.name
  policy_arn = aws_iam_policy.authorized-access.arn
}
