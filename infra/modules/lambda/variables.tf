variable "function_name" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "s3_bucket" {
  type = string
}

variable "memory_size" {
  type    = number
  default = 256
}

variable "timeout" {
  type    = number
  default = 20
}

variable "environment" {
  type    = map(string)
  default = {}
}

variable "log_retention_in_days" {
  type    = number
  default = 30
}

variable "api_id" {
  type    = string
  default = null
}

variable "api_execution_arn" {
  type    = string
  default = null
}

variable "integration_description" {
  type    = string
  default = null
}

variable "routes" {
  type    = list(string)
  default = []
}
