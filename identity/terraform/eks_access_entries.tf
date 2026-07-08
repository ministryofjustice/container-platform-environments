module "namespace_team_eks_access_entries_octo_nonlive" {
  for_each = local.namespace_access_teams
  source   = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.octo-nonlive-eks-access
  }

  permission_set_name = local.namespace_team_permission_set_names[each.key]
  assignments = {
    for key, assignment in local.namespace_team_access_assignments_octo_nonlive :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
    if assignment.kubernetes_group == each.key
  }

  depends_on = [module.namespace_team_readonly_eks]
}

module "namespace_team_eks_access_entries_octo_live" {
  for_each = local.namespace_access_teams
  source   = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.octo-live-eks-access
  }

  permission_set_name = local.namespace_team_permission_set_names[each.key]
  assignments = {
    for key, assignment in local.namespace_team_access_assignments_octo_live :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
    if assignment.kubernetes_group == each.key
  }

  depends_on = [module.namespace_team_readonly_eks]
}

module "cp_user_eks_access_entries_octo_nonlive" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.octo-nonlive-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    for key, assignment in local.cp_user_access_assignments_octo_nonlive :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
  }

  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}

module "cp_user_eks_access_entries_octo_live" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.octo-live-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    for key, assignment in local.cp_user_access_assignments_octo_live :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
  }

  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}
