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

module "namespace_team_eks_access_entries_hmpps_nonlive" {
  for_each = local.namespace_access_teams
  source   = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.hmpps-nonlive-eks-access
  }

  permission_set_name = local.namespace_team_permission_set_names[each.key]
  assignments = {
    for key, assignment in local.namespace_team_access_assignments_hmpps_nonlive :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
    if assignment.kubernetes_group == each.key
  }

  depends_on = [module.namespace_team_readonly_eks]
}

module "namespace_team_eks_access_entries_hmpps_live" {
  for_each = local.namespace_access_teams
  source   = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.hmpps-live-eks-access
  }

  permission_set_name = local.namespace_team_permission_set_names[each.key]
  assignments = {
    for key, assignment in local.namespace_team_access_assignments_hmpps_live :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
    if assignment.kubernetes_group == each.key
  }

  depends_on = [module.namespace_team_readonly_eks]
}

module "namespace_team_eks_access_entries_laa_nonlive" {
  for_each = local.namespace_access_teams
  source   = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.laa-nonlive-eks-access
  }

  permission_set_name = local.namespace_team_permission_set_names[each.key]
  assignments = {
    for key, assignment in local.namespace_team_access_assignments_laa_nonlive :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
    if assignment.kubernetes_group == each.key
  }

  depends_on = [module.namespace_team_readonly_eks]
}

module "namespace_team_eks_access_entries_laa_live" {
  for_each = local.namespace_access_teams
  source   = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.laa-live-eks-access
  }

  permission_set_name = local.namespace_team_permission_set_names[each.key]
  assignments = {
    for key, assignment in local.namespace_team_access_assignments_laa_live :
    key => {
      cluster          = assignment.cluster
      kubernetes_group = assignment.kubernetes_group
    }
    if assignment.kubernetes_group == each.key
  }

  depends_on = [module.namespace_team_readonly_eks]
}
