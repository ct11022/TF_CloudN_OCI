# Variable declarations for ubuntu instance setup

variable "tenancy_ocid" {
  type        = string
}
variable "user_ocid" {
  type        = string
}
variable "fingerprint" {
  type        = string
}
variable "private_key_path" {
  type        = string
}
variable "region" {
  type        = string
}
variable "resource_name_label" {
  type        = string
  description = "Resource name prefix label for ubuntu client"
}

variable "hostnum" {
  type        = string
  description = "Number to be used for ubuntu instance private ip host part"
  default     = "10"
}

variable "subnet_id" {
  type        = string
  description = "OCI subnet id to launch ubuntu instance"
}

variable "public_key" {
  type        = string
  description = "Public key for creating ubuntu instance"
}
