resource "aws_cloudwatch_log_group" "app" {
  name = "/my_sample_app/${terraform.workspace}"
}
