variable "image" {
  type = map(string)
  default = {
    "offer" : "WindowsServer"
    "publisher" : "MicrosoftWindowsServer"
    "sku" : "2022-datacenter-azure-edition"
    "version" : "latest"
  }
}

variable "ExternalIP" {
  type    = string
  default = "0.0.0.0"
}

variable "artifact_storage_account" {
  type    = string
  default = "demopsimages"
}

variable "artifact_storage_account_container" {
  type    = string
  default = "vhds"
}

variable "image_vhd_name" {
  type    = string
  default = "PixelStreamingWS2022"
}

variable "region" {
  type    = string
  default = "eastus"
}

variable "resource_group_name" {
  type    = string
  default = "demo-rg"
}

variable "temp_resource_group_name" {
  type    = string
  default = "td1rg2"
}

variable "temp_compute_name" {
  type    = string
  default = "td1cn2"
}

variable "vm_size" {
  type    = string
  default = "Standard_NV12s_v3"
}