variable "permission_set_name" {
  type = string
}

variable "assignments" {
  type = map(object({
    cluster          = string
    kubernetes_group = string
  }))
}
