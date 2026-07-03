# To Get Modernisation Platform Account Number
data "aws_ssm_parameter" "modernisation_platform_account_id" {
  name = "modernisation_platform_account_id"
}

data "aws_ssoadmin_instances" "this" {
  provider = aws.sso-management
}
