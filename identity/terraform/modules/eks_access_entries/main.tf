terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      configuration_aliases = [
        aws.eks_access,
      ]
    }
  }
}

data "aws_iam_roles" "permission_set_role" {
  for_each = var.assignments
  provider = aws.eks_access

  name_regex  = "^AWSReservedSSO_${var.permission_set_name}_[A-Za-z0-9]+$"
  path_prefix = "/aws-reserved/sso.amazonaws.com/"
}

resource "aws_eks_access_entry" "this" {
  for_each = var.assignments
  provider = aws.eks_access

  cluster_name      = each.value.cluster
  principal_arn     = one(data.aws_iam_roles.permission_set_role[each.key].arns)
  kubernetes_groups = [each.value.kubernetes_group]
  type              = "STANDARD"
}
