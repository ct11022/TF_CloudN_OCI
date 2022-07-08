# Outputs for ubuntu instance

output "ubuntu_id" {
  value = oci_core_instance.client.id
}

output "ubuntu_name" {
  value = oci_core_instance.client.display_name
}

output "ubuntu_state" {
  value = oci_core_instance.client.state
}

output "ubuntu_public_ip" {
  value = oci_core_instance.client.public_ip
}

output "ubuntu_private_ip" {
  value = oci_core_instance.client.private_ip
}
