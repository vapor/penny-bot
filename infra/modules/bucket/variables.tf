variable "name" {
  type = string
}

variable "object_ownership" {
  type    = string
  default = "BucketOwnerEnforced"
}

variable "versioning_enabled" {
  type    = bool
  default = false
}

variable "lifecycle_rules" {
  type = map(object({
    prefix                    = optional(string)
    object_size_less_than     = optional(number)
    noncurrent_days           = number
    newer_noncurrent_versions = number
  }))
  default = {}
}
