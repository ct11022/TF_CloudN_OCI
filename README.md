This is a terraform script is use for build a standard testbed with 1 Controller(in OCI) 1 Tr with HA, 1 Spoke with HA, 1 Spoke end VM in OCI CSP to CloudN testing 

## CloudN CaaG smoke test (OCI)

### Description

This Terraform configuration launches a new Aviatrix controller in AWS. Then, it initializes controller and installs with specific released version. It also configures 1 Spoke(HA) GWs and attaches to Transit(HA) GW in OCI

### Prerequisites

Provide testbed info such as controller password, license etc as necessary in provider_cred.tfvars file.
> aws_access_key = "Enter_AWS_access_key"  
> aws_secret_key = "Enter_AWS_secret_key"  
> aviatrix_controller_password = "Enter_your_controller_password"  
> aviatrix_admin_email  = "Enter_your_controller_admin_email"  
> aviatrix_license_id  = "Enter_license_ID_string_for_controller"  

> oci_tenancy_id = ""  
> oci_user_id = ""  
> oci_compartment_id = ""  
> oci_api_key_path = ""  
> oci_fingerprint = ""  
> oci_region = ""  

Provide testbed info such as controller password, license etc as necessary in terraform.tfvars file.
```
 testbed_name = ""  
 aws_region     = "The region you want to controller and spoke deploy"  
 keypair_name = "Use exsiting screct key in AWS for SSH login controller"  
 public_key_path = "Adding exsiting public key to spoke end vm"
 controller_vpc_id = "Deploy the controller on existing VPC"  
 controller_subnet_id = "The subnet ID belongs to above VPC"  
 controller_vpc_cidr  = "VPC CIDR"  
 upgrade_target_version = "it will be upgraded to the particular version of you assign"  
 incoming_ssl_cidr = ["0.0.0.0/0"] If the controller is used for OCI, reserve SSL CIDR 0.0.0.0/0.

 transit_vpc_id = "Deploy the Transit GW on existing VPC"
 transit_vpc_cidr = "VPC CIDR"
 transit_vpc_availability_domain = "US-SANJOSE-1-AD-1"
 transit_vpc_fault_domain = "FAULT-DOMAIN-1"
 transit_vpc_fault_domain_ha = "FAULT-DOMAIN-3"
 oci_dx_route_rules =[
    {
      destination       = "10.240.0.0/16" # Route Rule Destination CIDR
      destination_type  = "CIDR_BLOCK"     # only CIDR_BLOCK is supported at the moment
      description       = "To CaaG over private network"
      network_entity_id = "Next Hop OCID"
    },
    {
      destination       = "10.230.0.0/16"
      destination_type  = "CIDR_BLOCK"
      description       = "To CaaG over private network"
      network_entity_id = "Next Hop OCID"
    }
  ]
```


### Usage for Terraform
```
terraform init
terraform apply -var-file=provider_cred.tfvars -target=module.aviatrix_controller_initialize -auto-approve && terraform apply -var-file=provider_cred.tfvars -auto-approve
terraform show
terraform destroy -var-file=provider_cred.tfvars -auto-approve
terraform show
```

