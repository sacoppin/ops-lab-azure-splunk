variable "resource_group_name" {
  description = "The name of the existing Sandbox Resource Group"
  type        = string
}

variable "admin_password" {
  description = "Password for the VM admin user"
  type        = string
  sensitive   = true
}


variable "ssh_key_path" {
  description = " SSH key path"
  type        = string
}

variable "location" {
  description = "Region Azure"
  type        = string
  default     = "West Europe"
}