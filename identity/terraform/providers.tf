# AWS provider (default)
provider "aws" {
  region = "eu-west-2"
  default_tags { tags = local.tags }
}

# AWS provider (AWS root account for AWS SSO management)
provider "aws" {
  region = "eu-west-2"
  alias  = "sso-management"
  assume_role {
    role_arn = "arn:aws:iam::${local.environment_management.aws_organizations_root_account_id}:role/${local.sso_management_assume_role_name}"
  }
  default_tags { tags = local.tags }
}

# AWS provider (modernisation-secrets-read): Required for assuming a role into modernisation platform account to read secrets
provider "aws" {
  alias  = "modernisation-secrets-read"
  region = "eu-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${data.aws_ssm_parameter.modernisation_platform_account_id.value}:role/modernisation-account-limited-read-member-access"
  }
}

# AWS provider (octo nonlive account): Used to manage EKS access entries through a cross-account role.
provider "aws" {
  alias  = "octo-nonlive-eks-access"
  region = "eu-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${local.environment_management.account_ids[local.octo_nonlive_cluster]}:role/ContainerPlatformEKSAccess"
  }
  default_tags { tags = local.tags }
}

# AWS provider (octo live account): Used to manage EKS access entries through a cross-account role.
provider "aws" {
  alias  = "octo-live-eks-access"
  region = "eu-west-2"
  assume_role {
    role_arn = "arn:aws:iam::${local.environment_management.account_ids[local.octo_live_cluster]}:role/ContainerPlatformEKSAccess"
  }
  default_tags { tags = local.tags }
}
