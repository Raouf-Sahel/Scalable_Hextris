variable "remote_host" {
  description = "Public IP or hostname of the target VM"
  type        = string
}

variable "ssh_user" {
  description = "Username for SSH connection"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key" {
  description = "Private SSH key content used to connect to the VM"
  type        = string
  sensitive   = true
}

variable "timestamp" {
  description = "Timestamp to force remote re-provisioning (set dynamically by Jenkins)"
  type        = string
  default     = ""
}

