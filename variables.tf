variable "Name" {
  description = "The name to be used in tags"
  type        = string
  default     = "anisha"
}

variable "environment" {
  description = "The environment for the tags"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Name        = "anisha"
    Environment = "dev"
  }
}

