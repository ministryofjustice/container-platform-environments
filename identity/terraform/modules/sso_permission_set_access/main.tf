terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.sso_management,
      ]
    }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  provider = aws.sso_management

  instance_arn     = var.instance_arn
  name             = var.permission_set_name
  description      = var.permission_set_description
  session_duration = var.session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  provider = aws.sso_management

  instance_arn       = var.instance_arn
  managed_policy_arn = var.managed_policy_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  provider = aws.sso_management

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn
  inline_policy      = var.inline_policy_json
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = var.account_assignments
  provider = aws.sso_management

  instance_arn       = var.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this.arn

  principal_id   = var.principal_id
  principal_type = "GROUP"

  target_id   = each.value.target_id
  target_type = "AWS_ACCOUNT"
}
