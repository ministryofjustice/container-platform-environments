module "namespace_team_readonly_eks" {
  for_each = local.namespace_access_teams
  source   = "./modules/sso_permission_set_access"

  providers = {
    aws.sso_management = aws.sso-management
  }

  instance_arn               = one(data.aws_ssoadmin_instances.this.arns)
  permission_set_name        = local.namespace_team_permission_set_names[each.key]
  permission_set_description = "Read-only AWS and EKS viewer access for team ${each.key}"
  inline_policy_json         = data.aws_iam_policy_document.namespace_team_eks_view.json
  principal_id               = data.aws_identitystore_group.namespace_access_team[each.key].group_id

  account_assignments = {
    for key, assignment in local.namespace_team_access_assignments :
    key => assignment
    if assignment.kubernetes_group == each.key
  }
}

module "cp_user_eks_readonly_for_cp_engineers" {
  source = "./modules/sso_permission_set_access"

  providers = {
    aws.sso_management = aws.sso-management
  }

  instance_arn               = one(data.aws_ssoadmin_instances.this.arns)
  permission_set_name        = "cp-user-eks-readonly"
  permission_set_description = "Read-only AWS and EKS viewer access for cloud-platform-engineers"
  inline_policy_json         = data.aws_iam_policy_document.namespace_team_eks_view.json
  principal_id               = data.aws_identitystore_group.cloud_platform_engineers.group_id

  account_assignments = local.cp_user_access_assignments
}
