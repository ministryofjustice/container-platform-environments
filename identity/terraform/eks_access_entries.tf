data "aws_iam_roles" "namespace_team_permission_set_role_octo_nonlive" {
  for_each = local.namespace_team_cluster_assignments_octo_nonlive
  provider = aws.octo-nonlive-eks-access

  name_regex  = "^AWSReservedSSO_${local.namespace_team_permission_set_names[each.value.team]}_[A-Za-z0-9]+$"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"

  depends_on = [aws_ssoadmin_account_assignment.namespace_team_cluster]
}

data "aws_iam_roles" "namespace_team_permission_set_role_octo_live" {
  for_each = local.namespace_team_cluster_assignments_octo_live
  provider = aws.octo-live-eks-access

  name_regex  = "^AWSReservedSSO_${local.namespace_team_permission_set_names[each.value.team]}_[A-Za-z0-9]+$"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"

  depends_on = [aws_ssoadmin_account_assignment.namespace_team_cluster]
}

resource "aws_eks_access_entry" "namespace_team_octo_nonlive" {
  for_each = local.namespace_team_cluster_assignments_octo_nonlive
  provider = aws.octo-nonlive-eks-access

  cluster_name      = each.value.cluster
  principal_arn     = one(data.aws_iam_roles.namespace_team_permission_set_role_octo_nonlive[each.key].arns)
  kubernetes_groups = [each.value.team]
  type              = "STANDARD"
}

resource "aws_eks_access_entry" "namespace_team_octo_live" {
  for_each = local.namespace_team_cluster_assignments_octo_live
  provider = aws.octo-live-eks-access

  cluster_name      = each.value.cluster
  principal_arn     = one(data.aws_iam_roles.namespace_team_permission_set_role_octo_live[each.key].arns)
  kubernetes_groups = [each.value.team]
  type              = "STANDARD"
}
