variable "vcd_user" {
  description = "vCloud user"
}
variable "vcd_pass" {
  description = "vCloud password"
}
variable "vcd_allow_unverified_ssl" {
  default = true
}
variable "vcd_url" {
  description = "vCloud URL"
}
variable "org_name" {
  description = "vClooud Organization"
}
variable "org_vdc" {
  description = "vCloud Data center (VDC)"
}
variable "vcd_max_retry_timeout" {
  default = 120
}

# Connection for the VMware vCloud Director Provider
terraform {
  required_providers {
    vcd = {
      source  = "vmware/vcd"
      version = "3.12.1"
    }
  }
}

provider "vcd" {
  url      = var.vcd_url
  user     = var.vcd_user
  password = var.vcd_pass
  org      = var.org_name
  vdc      = var.org_vdc

  max_retry_timeout    = var.vcd_max_retry_timeout
  allow_unverified_ssl = var.vcd_allow_unverified_ssl

  logging = "true"
}
