testbed_name = "caag-oci-67tf"

# When region is changed, make sure AMI image is also changed.
aws_region     = "us-west-2"

#Use exsiting screct key for all testbed items SSH login.
keypair_name = "apitest"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCAcUJbggRnAxsfLkHLrSgHm3Fn0yk7u3jpDBjkAY79jwX8Tm92oXAYZvkGh6sE7MRGq3yYRfYdLll8h9cf0o69vFkJtn1EBE9XTgJ7rEWQCmEgCOJSZmADn9igWbBx6Tdix/nAk5zP68mYrcrJt6Zpn+UQXm7eys0ZGdmP3kqovjBWDOT/oYwyOGM96t/G9/Juod63ZkgIhZkona160ChAM+qS3FZeK0ya3mDzsPV9wpYcPjbzbOWZRPawUcaBn3TVfkA9PkS6UOem7elayHzhu7vU9XAKbJGSOwqNsaHX9DZIfsKkwOCI/onOi0sNqKhgyN9I6FHH43ZfwA+uLhfB"

# if user want to create controller at existng VPC, you need to fill enable following parameters
controller_vpc_id = "vpc-04d7383a3b654c4ec"
controller_subnet_id = "subnet-022278683e6b46764"
controller_vpc_cidr  = "10.109.0.0/16"

#controller will be upgraded to the particular version of you assign
upgrade_target_version = "6.7-patch"
# incoming_ssl_cidr = ["0.0.0.0/0"]

# if user want to create transit gw at existng VPC, you need to fill & enable following parameters
transit_vpc_id = "ocid1.vcn.oc1.us-sanjose-1.amaaaaaafiifhzia3jwmeqmo3c4exaocpz5knqbgllje6yp5apel7vez7wca~~ryan-auto-oci-sj1-myWest-AvxTransitVcn-1"
transit_vpc_cidr = "10.80.0.0/16"
transit_subnet_cidr = "10.88.9.128/26"
transit_ha_subnet_cidr = "10.88.9.192/26"
transit_vpc_availability_domain = "US-SANJOSE-1-AD-1"
transit_vpc_fault_domain = "FAULT-DOMAIN-1"
transit_vpc_fault_domain_ha = "FAULT-DOMAIN-3"
oci_dx_route_rules =[
    {
      destination       = "10.240.0.0/16" # Route Rule Destination CIDR
      destination_type  = "CIDR_BLOCK"     # only CIDR_BLOCK is supported at the moment
      description       = "To CaaG over private network"
      network_entity_id = "ocid1.drg.oc1.us-sanjose-1.aaaaaaaasccbhklkgbksw4ujjzn3lwr5y276rz4fjzjyclvfzt2q4akjrvza"
    },
    {
      destination       = "10.230.0.0/16"
      destination_type  = "CIDR_BLOCK"
      description       = "To CaaG over private network"
      network_entity_id = "ocid1.drg.oc1.us-sanjose-1.aaaaaaaasccbhklkgbksw4ujjzn3lwr5y276rz4fjzjyclvfzt2q4akjrvza"
    }
  ]


enable_caag = true
cloudn_hostname = "67.207.111.163"
cloudn_https_port = "64544"
caag_name = "vcloudn-144-awx-dx"
cloudn_bgp_asn = "65044"
cloudn_lan_interface_neighbor_ip = "10.210.34.100"
cloudn_lan_interface_neighbor_bgp_asn = "65219"
caag_connection_name = "vCN-144-apitest"
# vcn_restore_snapshot_name = "6.5"
# on_prem = "10.44.44.44"
