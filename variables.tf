variable "location" {
  description = "Location to deploy resources"
  type        = string
  default     = "WestEurope"
}

variable "username" {
  description = "Username for Virtual Machines"
  type        = string
  default     = "AzureAdmin"
}

variable "password" {
  description = "Password must meet Azure complexity requirements"
  type        = string
}

variable "vmsize" {
  description = "Size of the VMs"
  default     = "Standard_B2s"
}