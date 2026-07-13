# To Get Modernisation Platform Account Number
data "aws_ssm_parameter" "modernisation_platform_account_id" {
  name = "modernisation_platform_account_id"
}

data "aws_ssoadmin_instances" "this" {
  provider = aws.sso-management
}

data "aws_identitystore_group" "namespace_access_team" {
  for_each = local.namespace_access_teams

  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.key
    }
  }
}

data "aws_identitystore_group" "cloud_platform_engineers" {
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = "cloud-platform-engineers"
    }
  }
}

data "aws_iam_policy_document" "namespace_team_eks_view" {
  statement {
    sid    = "AllowEksConnectAndView"
    effect = "Allow"
    actions = [
      "eks:AccessKubernetesApi",
      "eks:Describe*",
      "eks:Get*",
      "eks:List*"
    ]
    resources = ["*"]
  }
}
