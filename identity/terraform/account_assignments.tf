resource "aws_ssoadmin_account_assignment" "namespace_team_cluster" {
  for_each = local.namespace_team_cluster_assignments
  provider = aws.sso-management

  instance_arn       = one(data.aws_ssoadmin_instances.this.arns)
  permission_set_arn = aws_ssoadmin_permission_set.namespace_team_readonly_eks[each.value.team].arn

  principal_id   = data.aws_identitystore_group.namespace_access_team[each.value.team].group_id
  principal_type = "GROUP"

  target_id   = local.environment_management.account_ids[each.value.cluster]
  target_type = "AWS_ACCOUNT"
}
