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

module "cp_user_eks_access_entries_hmpps_nonlive" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.hmpps-nonlive-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    "container-platform-hmpps-nonlive" = {
      cluster          = "container-platform-hmpps-nonlive"
      kubernetes_group = "cloud-platform-engineers"
    }
  }
  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}

module "cp_user_eks_access_entries_hmpps_live" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.hmpps-live-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    "container-platform-hmpps-live" = {
      cluster          = "container-platform-hmpps-live"
      kubernetes_group = "cloud-platform-engineers"
    }
  }
  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}

module "cp_user_eks_access_entries_laa_nonlive" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.laa-nonlive-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    "container-platform-laa-nonlive" = {
      cluster          = "container-platform-laa-nonlive"
      kubernetes_group = "cloud-platform-engineers"
    }
  }
  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}

module "cp_user_eks_access_entries_laa_live" {
  source = "./modules/eks_access_entries"

  providers = {
    aws.eks_access = aws.laa-live-eks-access
  }

  permission_set_name = "cp-user-eks-readonly"
  assignments = {
    "container-platform-laa-live" = {
      cluster          = "container-platform-laa-live"
      kubernetes_group = "cloud-platform-engineers"
    }
  }
  depends_on = [module.cp_user_eks_readonly_for_cp_engineers]
}
