## Aviatrix - Terraform Modules - Ubuntu Client Setup

### Description
This Terraform module creates an ubuntu instance in OCI test environment.

### Pre-requisites:
* An existing VPC
* An existing public subnet in that VPC
* Public-Private Key Pair

### Usage:

```
module "ubuntu-oci" {
  source              = "<<path to module>>"
  resource_name_label = "<<enter resource name prefix label>>"
  hostnum             = "<<enter host number>>"
  subnet_id           = "<<enter OCI public subnet id>>
  public_key          = "<<enter public key>>"
}
```

### Variables

- **resource_name_label**

Resource name prefix label for ubuntu client

- **hostnum**

Number to be used for ubuntu instance private ip host part

- **subnet_id**

OCI subnet id to launch ubuntu instance

- **public_key**

Public key for creating ubuntu instance


### Outputs

- **ubuntu_id**

Instance ID of the ubuntu instance

- **ubuntu_name**

Name the ubuntu instance

- **ubuntu_state**

Current state of the ubuntu instance

- **ubuntu_public_ip**

Public IP of the ubuntu instance

- **ubuntu_private_ip**

Private IP of the ubuntu instance
