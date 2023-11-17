output "controller_private_ip" {
  value = local.controller_pri_ip
}

output "controller_public_ip" {
  value = local.controller_pub_ip
}

output "transit_gw" {
  value = {
    name:aviatrix_transit_gateway.transit.gw_name,
    vpc_id: aviatrix_transit_gateway.transit.vpc_id
  }
}
output "spoke_gw" {
  value = {
    name: aviatrix_spoke_gateway.spoke[*].gw_name,
    vpc_id: aviatrix_spoke_gateway.spoke[*].vpc_id
  }
}
output "spoke_gw_name" {
  value = aviatrix_spoke_gateway.spoke[*].gw_name
}

output "spoke_public_vms_info" {
  value = {
        id : [module.ubuntu-oci.ubuntu_id],
        name : [module.ubuntu-oci.ubuntu_name],
        private_ip : [module.ubuntu-oci.ubuntu_private_ip],
        public_ip : [module.ubuntu-oci.ubuntu_public_ip]
  }
}

# output "spoke_private_vms_info" {
#   value = module.aws_spoke_vpc.ubuntu_private_vms[*]
# }

output "pem_filename" {
  value = (local.new_key ? local_file.cloud_pem[0].filename : null)
}
