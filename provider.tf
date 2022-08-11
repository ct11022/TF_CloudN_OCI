terraform {
  required_providers {
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
      version = "2.22.1"
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
  controller_ip           = local.new_vpc ? module.aviatrix_controller_build_new_vpc[0].public_ip : module.aviatrix_controller_build_existed_vpc[0].public_ip
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


# provider "github" {
#   token                  = var.github_token
#   alias                  = "login"
# }
