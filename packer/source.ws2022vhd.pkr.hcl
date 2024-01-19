source "azure-arm" "ws2022vhd" {
  azure_tags = {
    solution = "pixelstreaming-prereqs-vm"
  }
  os_type        = "Windows"
  communicator   = "winrm"
  winrm_username = "packer"
  winrm_timeout  = "10m"
  winrm_insecure = true
  winrm_use_ssl  = true

  # Input Image
  image_offer     = "${var.image.offer}"
  image_publisher = "${var.image.publisher}"
  image_sku       = "${var.image.sku}"
  image_version   = "${var.image.version}"

  # Build VM
  location                     = "${var.region}"
  temp_resource_group_name     = "${var.temp_resource_group_name}"
  temp_compute_name            = "${lower(replace(var.temp_compute_name, "_", "-"))}"
  vm_size                      = "${var.vm_size}"
  allowed_inbound_ip_addresses = ["${var.ExternalIP}"]

  # Output Managed Image
  use_azure_cli_auth                = true
  managed_image_resource_group_name = "${var.resource_group_name}"
  managed_image_name                = "${substr(var.temp_resource_group_name, 0, 23)}-{{isotime \"2006-01-02-1504\"}}"
}
