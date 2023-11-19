# Launch a new Aviatrix controller instance and initialize
# Configure a Spoke-GW with Aviatrix Transit solution

data "aws_caller_identity" "current" {}

locals {
  # Proper boolean usage
  new_key = (var.keypair_name == "" ? true : false)
}

# Public-Private key generation
resource "tls_private_key" "terraform_key" {
  count     = (local.new_key ? 1 : 0)
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "cloud_pem" {
  count           = (local.new_key ? 1 : 0)
  filename        = "cloudtls.pem"
  content         = tls_private_key.terraform_key[0].private_key_pem
  file_permission = "0600"
}

resource "random_id" "key_id" {
  count       = (local.new_key ? 1 : 0)
  byte_length = 4
}

# Create AWS keypair
resource "aws_key_pair" "controller" {
  count      = (local.new_key ? 1 : 0)
  key_name   = "controller-key-${random_id.key_id[0].dec}"
  public_key = tls_private_key.terraform_key[0].public_key_openssh
}

#Buile Aviatrix controller
module "aviatrix_controller_build" {
  source               = "git@github.com:AviatrixDev/terraform-aviatrix-aws-controller.git//modules/aviatrix-controller-build?ref=main"
  use_existing_vpc     = (var.controller_vpc_id != "" ? true : false)
  vpc_id               = var.controller_vpc_id
  subnet_id            = var.controller_subnet_id
  use_existing_keypair = true
  key_pair_name        = (local.new_key ? aws_key_pair.controller[0].key_name : var.keypair_name)
  ec2_role_name        = "aviatrix-role-ec2"
  name_prefix          = var.testbed_name
  allow_upgrade_jump   = true
  enable_ssh           = true
  release_infra        = var.release_infra
  ami_id               = var.aviatrix_controller_ami_id
  incoming_ssl_cidrs   = ["0.0.0.0/0"]
}

locals {
  controller_pub_ip           = module.aviatrix_controller_build.public_ip
  controller_pri_ip           = module.aviatrix_controller_build.private_ip
  iptable_ssl_cidr_jsonencode = jsonencode([for i in var.incoming_ssl_cidrs : { "addr" = i, "desc" = "" }])
}

#Initialize Controller
module "aviatrix_controller_initialize" {
  source                        = "git@github.com:AviatrixSystems/terraform-aviatrix-oci-controller.git//modules/aviatrix-controller-initialize?ref=master"
  avx_controller_public_ip      = local.controller_pub_ip
  avx_controller_private_ip     = local.controller_pri_ip
  avx_controller_admin_email    = var.aviatrix_admin_email
  avx_controller_admin_password = var.aviatrix_controller_password
  oci_tenancy_id                = var.oci_tenancy_id
  oci_user_id                   = var.oci_user_id
  oci_compartment_id            = var.oci_compartment_id
  oci_api_key_path              = var.oci_api_key_path
  account_email                 = var.aviatrix_admin_email
  access_account_name           = var.aviatrix_access_account
  aviatrix_customer_id          = var.aviatrix_license_id
  controller_version            = var.upgrade_target_version
  depends_on = [
    module.aviatrix_controller_build
  ]
}

resource "aws_security_group_rule" "ingress_rule_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.incoming_ssl_cidrs
  security_group_id = module.aviatrix_controller_build.security_group_id
  depends_on        = [module.aviatrix_controller_initialize]
}

# resource "null_resource" "call_api_set_allow_list" {
#   provisioner "local-exec" {
#     command = <<-EOT
#             AVTX_CID=$(curl -X POST  -k https://${local.controller_pub_ip}/v1/backend1 -d 'action=login_proc&username=admin&password=Aviatrix123#'| awk -F"\"" '{print $34}');
#             curl -k -v -X PUT https://${local.controller_pub_ip}/v2.5/api/controller/allow-list --header "Content-Type: application/json" --header "Authorization: cid $AVTX_CID" -d '{"allow_list": ${local.iptable_ssl_cidr_jsonencode}, "enable": true, "enforce": true}'
#         EOT
#   }
#   depends_on = [
#     module.aviatrix_controller_initialize
#   ]
# }

resource "aviatrix_controller_cert_domain_config" "controller_cert_domain" {
  provider    = aviatrix.new_controller
  cert_domain = var.cert_domain
  depends_on  = [module.aviatrix_controller_initialize]
}

# Create OCI Transit VPC
resource "aviatrix_vpc" "transit" {
  provider     = aviatrix.new_controller
  count        = (var.transit_vpc_id != "" ? 0 : 1)
  cloud_type   = 16
  account_name = var.aviatrix_access_account
  region       = var.transit_vpc_reg
  name         = "${var.testbed_name}-Tr-VPC"
  cidr         = "192.168.0.0/16"
  depends_on = [
    aviatrix_controller_cert_domain_config.controller_cert_domain
  ]
}

resource "time_sleep" "wait_60s" {
  create_duration = "60s"
  depends_on = [
    aviatrix_controller_cert_domain_config.controller_cert_domain
  ]
}

#Create an Aviatrix Transit Gateway
resource "aviatrix_transit_gateway" "transit" {
  provider               = aviatrix.new_controller
  cloud_type             = 16
  account_name           = var.aviatrix_access_account
  gw_name                = "${var.testbed_name}-Transit-GW"
  vpc_id                 = (var.transit_vpc_id != "" ? var.transit_vpc_id : aviatrix_vpc.transit[0].vpc_id)
  vpc_reg                = var.transit_vpc_reg
  gw_size                = var.transit_gw_size
  subnet                 = (var.transit_vpc_cidr != "" ? var.transit_subnet_cidr : cidrsubnet(aviatrix_vpc.transit[0].cidr, 10, 16))
  insane_mode            = true
  ha_subnet              = (var.transit_vpc_cidr != "" ? var.transit_ha_subnet_cidr : cidrsubnet(aviatrix_vpc.transit[0].cidr, 10, 22))
  ha_gw_size             = var.transit_gw_size
  single_ip_snat         = false
  connected_transit      = true
  availability_domain    = (var.transit_vpc_availability_domain != "" ? var.transit_vpc_availability_domain : aviatrix_vpc.transit[0].availability_domains[0])
  fault_domain           = (var.transit_vpc_fault_domain != "" ? var.transit_vpc_fault_domain : aviatrix_vpc.transit[0].fault_domains[0])
  ha_availability_domain = (var.transit_vpc_availability_domain != "" ? var.transit_vpc_availability_domain : aviatrix_vpc.transit[0].availability_domains[0])
  ha_fault_domain        = (var.transit_vpc_fault_domain_ha != "" ? var.transit_vpc_fault_domain_ha : aviatrix_vpc.transit[0].fault_domains[1])
  depends_on = [
    time_sleep.wait_60s
  ]
  lifecycle {
    ignore_changes = [
      vpc_id,
    ]
  }

}

# Create OCI Spoke VPC
resource "aviatrix_vpc" "spoke_vpc" {
  provider     = aviatrix.new_controller
  cloud_type   = 16
  account_name = var.aviatrix_access_account
  region       = var.spoke_vpc_reg
  name         = "${var.testbed_name}-spoke"
  cidr         = var.spoke_cidr
  depends_on = [
    aviatrix_controller_cert_domain_config.controller_cert_domain
  ]
}

# Create OCI Spoke VPC VM
module "ubuntu-oci" {
  source              = "./ubuntu-oci"
  resource_name_label = "${var.testbed_name}-spoke"
  hostnum             = 10
  subnet_id           = aviatrix_vpc.spoke_vpc.public_subnets[0].subnet_id
  public_key          = (local.new_key ? tls_private_key.terraform_key[0].public_key_openssh : file(var.public_key_path))
  tenancy_ocid        = var.oci_tenancy_id
  user_ocid           = var.oci_user_id
  fingerprint         = var.oci_fingerprint
  private_key_path    = var.oci_api_key_path
  region              = var.oci_region
}

resource "time_sleep" "wait_20s" {
  create_duration = "20s"
  depends_on = [
    aviatrix_transit_gateway.transit
  ]
}
#Create an Aviatrix Spoke Gateway-1
resource "aviatrix_spoke_gateway" "spoke" {
  provider            = aviatrix.new_controller
  count               = 1
  cloud_type          = 16
  account_name        = var.aviatrix_access_account
  gw_name             = "${var.testbed_name}-Spoke-GW-${count.index}"
  vpc_id              = aviatrix_vpc.spoke_vpc.vpc_id
  vpc_reg             = var.spoke_vpc_reg
  gw_size             = var.spoke_gw_size
  subnet              = aviatrix_vpc.spoke_vpc.public_subnets[0].cidr
  manage_ha_gateway   = false
  availability_domain = aviatrix_vpc.spoke_vpc.availability_domains[0]
  fault_domain        = aviatrix_vpc.spoke_vpc.fault_domains[0]
  depends_on = [
    aviatrix_vpc.spoke_vpc,
    time_sleep.wait_20s
  ]
}

# Create an Aviatrix OCI Spoke HA Gateway
resource "aviatrix_spoke_ha_gateway" "spoke_ha" {
  provider            = aviatrix.new_controller
  count               = 1
  primary_gw_name     = aviatrix_spoke_gateway.spoke[count.index].id
  gw_name             = "${var.testbed_name}-Spoke-GW-${count.index}-ha"
  gw_size             = var.spoke_gw_size
  subnet              = aviatrix_vpc.spoke_vpc.public_subnets[0].cidr
  availability_domain = aviatrix_vpc.spoke_vpc.availability_domains[0]
  fault_domain        = aviatrix_vpc.spoke_vpc.fault_domains[2]
}

# Create Spoke-Transit Attachment
resource "aviatrix_spoke_transit_attachment" "spoke" {
  provider        = aviatrix.new_controller
  count           = 1
  spoke_gw_name   = aviatrix_spoke_gateway.spoke[count.index].gw_name
  transit_gw_name = aviatrix_transit_gateway.transit.gw_name
  depends_on = [
    aviatrix_spoke_ha_gateway.spoke_ha
  ]
}

#Follwing block is use for create the route table in transit in OCI, it makes the traffic routing from Spoke to CloudN.
locals {
  pure_oci_tr_vcn_id = (var.transit_vpc_id != "" ? split("~~", var.transit_vpc_id)[0] : null)
}
output "pure_oci_tr_vcn_id" {
  value = local.pure_oci_tr_vcn_id
}
data "oci_core_internet_gateways" "tr_internet_gateway" {
  count          = (local.pure_oci_tr_vcn_id != null ? 1 : 0)
  compartment_id = var.oci_compartment_id
  vcn_id         = local.pure_oci_tr_vcn_id
}
data "oci_core_subnets" "tr_subnet" {
  count          = (local.pure_oci_tr_vcn_id != null ? 1 : 0)
  compartment_id = var.oci_compartment_id
  vcn_id         = local.pure_oci_tr_vcn_id
  display_name   = "av-gw-${aviatrix_transit_gateway.transit.gw_name}"
}

data "oci_core_subnets" "tr_ha_subnet" {
  count          = (local.pure_oci_tr_vcn_id != null ? 1 : 0)
  compartment_id = var.oci_compartment_id
  vcn_id         = local.pure_oci_tr_vcn_id
  display_name   = "av-gw-${aviatrix_transit_gateway.transit.ha_gw_name}"
}

#Create a new route table to transit route spokes to cloudn
resource "oci_core_route_table" "tr_dx_route_table" {
  count          = (local.pure_oci_tr_vcn_id != null ? 1 : 0)
  compartment_id = var.oci_compartment_id
  vcn_id         = data.oci_core_internet_gateways.tr_internet_gateway[count.index].vcn_id
  display_name   = "av-gw-${aviatrix_transit_gateway.transit.gw_name}-2"
  route_rules {
    network_entity_id = data.oci_core_internet_gateways.tr_internet_gateway[count.index].gateways[0].id
    description       = "Internet Gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
  dynamic "route_rules" {
    for_each = var.oci_dx_route_rules

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      description       = route_rules.value.description
      network_entity_id = route_rules.value.network_entity_id
    }
  }
}

#Create a new route table to transit ha routes spoke to cloudn
resource "oci_core_route_table" "tr_ha_dx_route_table" {
  count          = (local.pure_oci_tr_vcn_id != null ? 1 : 0)
  compartment_id = var.oci_compartment_id
  vcn_id         = data.oci_core_internet_gateways.tr_internet_gateway[count.index].vcn_id
  display_name   = "av-gw-${aviatrix_transit_gateway.transit.ha_gw_name}-2"
  route_rules {
    network_entity_id = data.oci_core_internet_gateways.tr_internet_gateway[count.index].gateways[0].id
    description       = "Internet Gateway"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
  dynamic "route_rules" {
    for_each = var.oci_dx_route_rules

    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      description       = route_rules.value.description
      network_entity_id = route_rules.value.network_entity_id
    }
  }
}

#Attach new route table to transit subet
resource "oci_core_route_table_attachment" "tr_route_table2_attachment" {
  count          = (var.transit_vpc_id != "" ? 1 : 0)
  subnet_id      = data.oci_core_subnets.tr_subnet[count.index].subnets[0].id
  route_table_id = oci_core_route_table.tr_dx_route_table[count.index].id
}

#Attach new route table to transit ha subet
resource "oci_core_route_table_attachment" "tr_ha_route_table2_attachment" {
  count          = (var.transit_vpc_id != "" ? 1 : 0)
  subnet_id      = data.oci_core_subnets.tr_ha_subnet[count.index].subnets[0].id
  route_table_id = oci_core_route_table.tr_ha_dx_route_table[count.index].id
}
