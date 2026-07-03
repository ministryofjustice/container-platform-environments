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

resource "aws_ssoadmin_permission_set" "namespace_team_readonly_eks" {
  for_each = local.namespace_access_teams
  provider = aws.sso-management

  instance_arn     = one(data.aws_ssoadmin_instances.this.arns)
  name             = local.namespace_team_permission_set_names[each.key]
  description      = "Read-only AWS and EKS viewer access for team ${each.key}"
  session_duration = "PT8H"
}

resource "aws_ssoadmin_managed_policy_attachment" "namespace_team_readonly" {
  for_each = local.namespace_access_teams
  provider = aws.sso-management

  instance_arn       = one(data.aws_ssoadmin_instances.this.arns)
  managed_policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.namespace_team_readonly_eks[each.key].arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "namespace_team_eks_view" {
  for_each = local.namespace_access_teams
  provider = aws.sso-management

  instance_arn       = one(data.aws_ssoadmin_instances.this.arns)
  permission_set_arn = aws_ssoadmin_permission_set.namespace_team_readonly_eks[each.key].arn
  inline_policy      = data.aws_iam_policy_document.namespace_team_eks_view.json
}
