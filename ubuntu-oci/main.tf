provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}

data "oci_core_subnet" "test_subnet" {
    subnet_id = var.subnet_id
}

data "oci_identity_availability_domains" "ADs" {
  compartment_id = data.oci_core_subnet.test_subnet.compartment_id
}

data "oci_core_images" "ubuntu" {
  compartment_id           = data.oci_core_subnet.test_subnet.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "20.04"
  shape                    = "VM.Standard2.1"
}

resource "oci_core_instance" "client" {
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[0].name
  compartment_id      = data.oci_core_subnet.test_subnet.compartment_id
  display_name        = "${var.resource_name_label}-ubuntu"
  shape               = "VM.Standard2.1"

  create_vnic_details {
    subnet_id        = var.subnet_id
    display_name     = "${var.resource_name_label}-ubuntu-nic"
    assign_public_ip = true
    hostname_label   = "${var.resource_name_label}-ubuntu"
    private_ip       = cidrhost(data.oci_core_subnet.test_subnet.cidr_block,var.hostnum)
  }

  source_details {
    source_type = "image"
    source_id = data.oci_core_images.ubuntu.images[0].id
  }

  metadata = {
    ssh_authorized_keys = var.public_key
  }
}
