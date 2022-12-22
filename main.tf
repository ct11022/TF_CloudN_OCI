# Launch a new Aviatrix controller instance and initialize
# Configure a Spoke-GW with Aviatrix Transit solution

data "aws_caller_identity" "current" {}

locals {
  # Proper boolean usage
  new_vpc = (var.controller_vpc_id == "" || var.controller_subnet_id == "" ? true : false)
  new_key = (var.keypair_name == "" || var.ssh_public_key == "" ? true : false)
}


# Create AWS VPC for Aviatrix Controller
resource "aws_vpc" "controller" {
  count            = (local.new_vpc ? 1 : 0)
  cidr_block       = "10.55.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "${var.testbed_name} Controller VPC"
  }
}

# Create AWS Subnet for Aviatrix Controller
resource "aws_subnet" "controller" {
  count      = (local.new_vpc ? 1 : 0)
  vpc_id     = aws_vpc.controller[0].id
  cidr_block = "10.55.1.0/24"

  tags = {
    Name = "${var.testbed_name} Controller Subnet"
  }
  depends_on = [
    aws_vpc.controller
  ]
}

# Public-Private key generation
resource "tls_private_key" "terraform_key" {
  count     = (local.new_key ? 1 : 0)
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "cloud_pem" {
  count     = (local.new_key ? 1 : 0)
  filename        = "cloudtls.pem"
  content         = tls_private_key.terraform_key[0].private_key_pem
  file_permission = "0600"
}

resource "random_id" "key_id" {
  count     = (local.new_key ? 1 : 0)
	byte_length = 4
}

# Create AWS keypair
resource "aws_key_pair" "controller" {
  count     = (local.new_key ? 1 : 0)
  key_name   = "controller-key-${random_id.key_id[0].dec}"
  public_key = tls_private_key.terraform_key[0].public_key_openssh
}

# Build Aviatrix controller instance with new create vpc
module "aviatrix_controller_build_new_vpc" {
  count          = (local.new_vpc ? 1 : 0)
  source         = "./aviatrix_controller_build"
  vpc_id         = aws_vpc.controller[0].id
  subnet_id      = aws_subnet.controller[0].id
  keypair_name   = (local.new_key ? aws_key_pair.controller[0].key_name : var.keypair_name)
  name = "${var.testbed_name}-Controller"
  incoming_ssl_cidr = ["0.0.0.0/0"]
  ssh_cidrs = var.incoming_ssl_cidr
}

#Buile Aviatrix controller at existed VPC
module "aviatrix_controller_build_existed_vpc" {
  count   = (local.new_vpc ? 0 : 1)
  source  = "git@github.com:AviatrixDev/terraform-modules-aws-internal.git//aviatrix-controller-build?ref=main"
  vpc     = var.controller_vpc_id
  subnet  = var.controller_subnet_id
  keypair = (local.new_key ? aws_key_pair.controller[0].key_name : var.keypair_name)
  ec2role = "aviatrix-role-ec2"
  type = "BYOL"
  termination_protection = false
  controller_name = "${var.testbed_name}-Controller"
  name_prefix = var.testbed_name
  root_volume_size = "64"
  incoming_ssl_cidr = ["0.0.0.0/0"]
  ssh_cidrs = var.incoming_ssl_cidr
}

resource "time_sleep" "wait_210s" {
  create_duration = "240s"
  depends_on                    = [
    module.aviatrix_controller_build_existed_vpc,
    module.aviatrix_controller_build_new_vpc
  ]
}

locals {
  controller_pub_ip = local.new_vpc ? module.aviatrix_controller_build_new_vpc[0].public_ip : module.aviatrix_controller_build_existed_vpc[0].public_ip
  controller_pri_ip = local.new_vpc ? module.aviatrix_controller_build_new_vpc[0].private_ip : module.aviatrix_controller_build_existed_vpc[0].private_ip
  iptable_ssl_cidr_jsonencode = jsonencode([for i in var.incoming_ssl_cidr :  {"addr"= i, "desc"= "" }])
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
  depends_on                    = [
    time_sleep.wait_210s
  ]
}

resource "null_resource" "call_api_set_allow_list" {
  provisioner "local-exec" {
    command = <<-EOT
            AVTX_CID=$(curl -X POST  -k https://${local.controller_pub_ip}/v1/backend1 -d 'action=login_proc&username=admin&password=Aviatrix123#'| awk -F"\"" '{print $34}');
            curl -k -v -X PUT https://${local.controller_pub_ip}/v2.5/api/controller/allow-list --header "Content-Type: application/json" --header "Authorization: cid $AVTX_CID" -d '{"allow_list": ${local.iptable_ssl_cidr_jsonencode}, "enable": true, "enforce": true}'
        EOT
  }
  depends_on = [
    module.aviatrix_controller_initialize
  ]
}

resource "aviatrix_controller_cert_domain_config" "controller_cert_domain" {
    provider    = aviatrix.new_controller
    cert_domain = var.cert_domain
    depends_on  = [
      null_resource.call_api_set_allow_list
    ]
}

# Create OCI Transit VPC
resource "aviatrix_vpc" "transit" {
  provider             = aviatrix.new_controller
  count                = (var.transit_vpc_id != "" ? 0 : 1)
  cloud_type           = 16
  account_name         = var.aviatrix_access_account
  region               = var.transit_vpc_reg
  name                 = "${var.testbed_name}-Tr-VPC"
  cidr                 = "192.168.0.0/16"
  depends_on           = [
    aviatrix_controller_cert_domain_config.controller_cert_domain
  ]
}

resource "time_sleep" "wait_60s" {
  create_duration = "60s"
  depends_on      = [
    aviatrix_controller_cert_domain_config.controller_cert_domain
  ]
}

#Create an Aviatrix Transit Gateway
resource "aviatrix_transit_gateway" "transit" {
  provider                 = aviatrix.new_controller
  cloud_type               = 16
  account_name             = var.aviatrix_access_account
  gw_name                  = "${var.testbed_name}-Transit-GW"
  vpc_id                   = (var.transit_vpc_id != "" ? var.transit_vpc_id : aviatrix_vpc.transit[0].vpc_id)
  vpc_reg                  = var.transit_vpc_reg
  gw_size                  = var.transit_gw_size
  subnet                   = (var.transit_vpc_cidr != "" ? var.transit_subnet_cidr : cidrsubnet(aviatrix_vpc.transit[0].cidr, 10, 16))
  insane_mode              = true
  ha_subnet                = (var.transit_vpc_cidr != "" ? var.transit_ha_subnet_cidr : cidrsubnet(aviatrix_vpc.transit[0].cidr, 10, 22))
  ha_gw_size               = var.transit_gw_size
  single_ip_snat           = false
  connected_transit        = true
  availability_domain = (var.transit_vpc_availability_domain != "" ? var.transit_vpc_availability_domain : aviatrix_vpc.transit[0].availability_domains[0])
  fault_domain        = (var.transit_vpc_fault_domain != "" ? var.transit_vpc_fault_domain : aviatrix_vpc.transit[0].fault_domains[0])
  ha_availability_domain = (var.transit_vpc_availability_domain != "" ? var.transit_vpc_availability_domain : aviatrix_vpc.transit[0].availability_domains[0])
  ha_fault_domain        = (var.transit_vpc_fault_domain_ha != "" ? var.transit_vpc_fault_domain_ha : aviatrix_vpc.transit[0].fault_domains[1])
  depends_on               = [
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
  provider             = aviatrix.new_controller
  cloud_type           = 16
  account_name         = var.aviatrix_access_account
  region               = var.spoke_vpc_reg
  name                 = "${var.testbed_name}-spoke"
  cidr                 = var.spoke_cidr
  depends_on           = [
    aviatrix_controller_cert_domain_config.controller_cert_domain
  ]
}

# Create OCI Spoke VPC VM
module "ubuntu-oci" {
  source              = "./ubuntu-oci"
  resource_name_label = "${var.testbed_name}-spoke"
  hostnum             = 10
  subnet_id           = aviatrix_vpc.spoke_vpc.public_subnets[0].subnet_id
  public_key          = (local.new_key ? tls_private_key.terraform_key[0].public_key_openssh : var.ssh_public_key)
  tenancy_ocid        = var.oci_tenancy_id
  user_ocid           = var.oci_user_id
  fingerprint         = var.oci_fingerprint
  private_key_path    = var.oci_api_key_path
  region              = var.oci_region
}

resource "time_sleep" "wait_20s" {
  create_duration = "20s"
  depends_on      = [
    aviatrix_transit_gateway.transit
  ]
}
#Create an Aviatrix Spoke Gateway-1
resource "aviatrix_spoke_gateway" "spoke" {
  provider                          = aviatrix.new_controller
  count                             = 1
  cloud_type                        = 16
  account_name                      = var.aviatrix_access_account
  gw_name                           = "${var.testbed_name}-Spoke-GW-${count.index}"
  vpc_id                            = aviatrix_vpc.spoke_vpc.vpc_id
  vpc_reg                           = var.spoke_vpc_reg
  gw_size                           = var.spoke_gw_size
  subnet                            = aviatrix_vpc.spoke_vpc.public_subnets[0].cidr
  manage_ha_gateway = false
  availability_domain               = aviatrix_vpc.spoke_vpc.availability_domains[0]
  fault_domain                      = aviatrix_vpc.spoke_vpc.fault_domains[0]
  depends_on                 = [
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
  pure_oci_tr_vcn_id = (var.transit_vpc_id != "" ? split("~~", var.transit_vpc_id)[0]: null)
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
  route_table_id =oci_core_route_table.tr_dx_route_table[count.index].id
}

#Attach new route table to transit ha subet
resource "oci_core_route_table_attachment" "tr_ha_route_table2_attachment" {
  count          = (var.transit_vpc_id != "" ? 1 : 0)
  subnet_id      = data.oci_core_subnets.tr_ha_subnet[count.index].subnets[0].id
  route_table_id = oci_core_route_table.tr_ha_dx_route_table[count.index].id
}

# Following is CloudN Registration and Attachment.
# locals {
#   cloudn_url = "${var.cloudn_hostname}:${var.cloudn_https_port}"
# }

# #Reset CloudN
# resource "null_resource" "reset_cloudn" {
#   count = (var.enable_caag ? 1 : 0)
#   provisioner "local-exec" {
#     command = <<-EOT
#             AVTX_CID=$(curl -X POST  -k https://${local.cloudn_url}/v1/backend1 -d 'action=login_proc&username=admin&password=Aviatrix123#'| awk -F"\"" '{print $34}');
#             curl -X POST  -k https://${local.cloudn_url}/v1/api -d "action=reset_caag_to_cloudn_factory_state_by_cloudn&CID=$AVTX_CID"
#         EOT
#   }
# }

# resource "time_sleep" "wait_120_seconds" {
#   count      = (var.enable_caag ? 1 : 0)
#   depends_on = [null_resource.reset_cloudn]

#   create_duration = "120s"
# }

# # Register a CloudN to Controller
# resource "aviatrix_cloudn_registration" "cloudn_registration" {
#   provider        = aviatrix.new_controller
#   count           = (var.enable_caag ? 1 : 0)
#   name            = var.caag_name
#   username        = var.aviatrix_controller_username
#   password        = var.aviatrix_controller_password
#   address         = local.cloudn_url

#   depends_on      = [
#     time_sleep.wait_120_seconds
#   ]
# 	lifecycle {
# 		ignore_changes = all
# 	}
# }

# resource time_sleep wait_30_s{
#   create_duration = "30s"
#   depends_on = [
#     aviatrix_cloudn_registration.cloudn_registration
#   ]
# }

# # Create a CloudN Transit Gateway Attachment
# resource "aviatrix_cloudn_transit_gateway_attachment" "caag" {
#   provider                              = aviatrix.new_controller
#   count                                 = (var.enable_caag ? 1 : 0)
#   device_name                           = var.caag_name
#   transit_gateway_name                  = aviatrix_transit_gateway.transit.gw_name
#   connection_name                       = var.caag_connection_name
#   transit_gateway_bgp_asn               = var.transit_gateway_bgp_asn
#   cloudn_bgp_asn                        = var.cloudn_bgp_asn
#   cloudn_lan_interface_neighbor_ip      = var.cloudn_lan_interface_neighbor_ip
#   cloudn_lan_interface_neighbor_bgp_asn = var.cloudn_lan_interface_neighbor_bgp_asn
#   enable_over_private_network           = var.enable_over_private_network 
#   enable_jumbo_frame                    = false
#   depends_on = [
#     aviatrix_transit_gateway.transit,
#     time_sleep.wait_30_s
#   ]
# }
