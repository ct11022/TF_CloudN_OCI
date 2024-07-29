variable "testbed_name" { default = "TFawsCaaG" }
variable "aws_region" { default = "us-west-2" }
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "oci_tenancy_id" {}
variable "oci_user_id" {}
variable "oci_compartment_id" {}
variable "oci_api_key_path" {}
variable "oci_fingerprint" {}
variable "oci_region" {}

variable "aviatrix_controller_username" { default = "admin" }
variable "aviatrix_controller_password" { default = "Aviatrix123#" }
variable "aviatrix_admin_email" { default = "jchang@aviatrix.com" }
variable "aviatrix_controller_ami_id" { default = "" }
variable "aviatrix_oci_access_account" { default = "oci1" }
variable "aviatrix_aws_access_account" { default = "aws1" }
variable "aviatrix_license_id" {}
variable "upgrade_target_version" { default = "6.7-patch" }
variable "release_infra" { default = "staging" }
variable "controller_type_of_billing" { default = "G3" }

variable "transit_vpc_id" {
  description = "for private network, the transit vpc id"
  default     = ""
}
variable "transit_vpc_reg" {
  description = "for private network, the transit vpc region"
  default     = "us-sanjose-1"
}
variable "transit_vpc_cidr" {
  description = "for private network, the transit vpc cidr"
  default     = ""
}
variable "transit_subnet_cidr" {
  description = "Create in the exsitsor private network, the transit sunbet cidr"
  default     = ""
}

variable "transit_ha_subnet_cidr" {
  description = "Create in the exsits private network, the transit ha subnet cidr"
  default     = ""
}
variable "transit_vpc_availability_domain" {
  description = "for private network,the transit vpc availability domain"
  default     = ""
}
variable "transit_vpc_fault_domain" {
  description = "for private network, the transit vpc fault domain"
  default     = ""
}
variable "transit_vpc_fault_domain_ha" {
  description = "for private network, the transit vpc fault domain ha"
  default     = ""
}
variable "transit_gw_size" {
  description = "Size of the gateway instance"
  default     = "VM.Standard2.4"
}
variable "oci_dx_route_rules" {
  description = "DX rules to CaaG over private network"
  type = list(object({
    destination       = string
    description       = string
    destination_type  = string
    network_entity_id = string
  }))
  default = [{
    description       = "value"
    destination       = "value"
    destination_type  = "value"
    network_entity_id = "value"
  }]
}
variable "spoke_vpc_reg" {
  description = "spoke vpc region"
  default     = "us-sanjose-1"
}
variable "spoke_gw_size" {
  description = "Size of the gateway instance"
  default     = "VM.Standard2.2"
}
variable "spoke_count" {
  description = "The number of spokes to create."
  default     = 1
}
variable "spoke_cidr" {
  description = "Spoke CIDR."
  default     = "10.20.0.0/16"
}
variable "spoke_ha_postfix_name" {
  description = "A string to append to the spoke_ha name."
  default     = "hagw"
}
variable "controller_vpc_id" {
  description = "create controller at existed vpc"
  default     = ""
}
variable "controller_vpc_cidr" {
  description = "create controller at existed vpc"
  default     = ""
}
variable "controller_subnet_id" {
  description = "create controller at existed vpc"
  default     = ""
}
variable "keypair_name" {
  description = "use the key saved on aws"
  default     = ""
}
variable "public_key_path" {
  description = ""
  default     = ""
}
variable "incoming_ssl_cidrs" {
  type        = list(string)
  description = "The CIDR to be allowed for HTTPS(port 443) access to the controller. Type is \"list\"."
  default     = ["0.0.0.0/0"]
}
variable "cert_domain" {
  type    = string
  default = "caag.com"
}
