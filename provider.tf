terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
      version = "2.24.3"
    }
    aws = {
      source = "hashicorp/aws"
    }
    oci = {
      source = "oracle/oci"
      version = "4.87.0"
    }
  }
}
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

provider "aviatrix" {
  controller_ip           = local.controller_pub_ip
  username                = var.aviatrix_controller_username
  password                = var.aviatrix_controller_password
  skip_version_validation = true
  alias                   = "new_controller"
}

provider "oci" {
  tenancy_ocid     = var.oci_tenancy_id
  user_ocid        = var.oci_user_id
  fingerprint      = var.oci_fingerprint
  private_key_path = var.oci_api_key_path
  region           = var.oci_region
}
