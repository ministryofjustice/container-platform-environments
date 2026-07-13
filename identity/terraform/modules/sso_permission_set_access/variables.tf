variable "instance_arn" {
  type = string
}

variable "permission_set_name" {
  type = string
}

variable "permission_set_description" {
  type = string
}

variable "session_duration" {
  type    = string
  default = "PT8H"
}

variable "managed_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

variable "inline_policy_json" {
  type = string
}

variable "principal_id" {
  type = string
}

variable "account_assignments" {
  type = map(object({
    cluster          = string
    target_id        = string
    kubernetes_group = string
  }))
}
