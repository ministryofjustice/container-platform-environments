# Creates access entries for the cloud-platform-engineers permission set so that they can access in the same way as users for troubleshooting

module "cp_user_eks_access_entries_octo_nonlive" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.octo-nonlive-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    "container-platform-octo-nonlive" = {
      cluster          = "container-platform-octo-nonlive"
      kubernetes_group = "cloud-platform-engineers"
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
    "container-platform-octo-live" = {
      cluster          = "container-platform-octo-live"
      kubernetes_group = "cloud-platform-engineers"
    }
  }

  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}
