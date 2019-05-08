# CloudInit Variables
variable "user_name" {}
variable "ssh_authorized-key" {}

# Libvirt Variables
variable "libvirt_uri" {
  description = "URI of server running libvirtd"
  default = "qemu:///system"
}

variable "prefix" {
  description = "Resources will be prefixed with this to avoid clashing names"
  default = "dmz-lb"
}

variable "guest_count" {
  description = "Number of Guests to Create"
  default     = "1"
}

variable "libvirt_volume_source" {
  description = "Volume Image Source"
  default = "https://cloud-images.ubuntu.com/releases/bionic/release/ubuntu-18.04-server-cloudimg-amd64.img"
}

variable "libvirt_volume_pool" {
  description = "Volume Storage Pool"
  default = "default"
}

variable "libvirt_volume_size" {
  description = "Volume Size in Bytes"
  default = "17179869184"
}

variable "mac_prefix" {
  description = "Must change before deploying in new subnet"
  default = "52:54:00:00:AC"
}

variable "hostname" {
  description = "Guest Hostname"
  default     = "k8s-lb"
}

variable "nameserver" {
  description = "Default DNS server for host"
  default     = "127.0.0.1"
}

variable "domain_name" {
  description = "Default Domain Name for host"
  default     = "xip.io"
}

variable "memory" {
  default = "2048"
}

variable "vcpu" {
  default = "2"
}

variable "network" {
  description = "Name of Libvirt Network"
  default = "default"
}

variable "port_group" {
  description = "Namve of OVS Port Group"
  default = "default"
}
