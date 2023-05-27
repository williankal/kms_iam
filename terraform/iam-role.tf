resource "aws_iam_role" "authorized-access-role" {
  name = "authorized-access-role"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  }

resource "aws_iam_role_policy_attachment" "authorized_access-attach" {
  role       = aws_iam_role.authorized-access-role.name
  policy_arn = aws_iam_policy.authorized-access.arn
}

