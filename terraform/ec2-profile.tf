resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "authorized-access-role"
}
