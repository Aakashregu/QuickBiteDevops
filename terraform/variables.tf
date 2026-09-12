variable "aws_region" {
  description = "AWS region; keep your AWS Console in this same region."
  type        = string
  default     = "ap-south-1"
}

variable "admin_cidr" {
  description = "Your LAPTOP's current public IPv4 address followed by /32."
  type        = string
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && can(regex("/32$", var.admin_cidr))
    error_message = "Use one IPv4 address followed by /32, not 0.0.0.0/0."
  }
}

variable "bootstrap_cidr" {
  description = "The temporary bootstrap EC2 public IPv4 address followed by /32."
  type        = string
  validation {
    condition     = can(cidrhost(var.bootstrap_cidr, 0)) && can(regex("/32$", var.bootstrap_cidr))
    error_message = "Use the bootstrap public IPv4 address followed by /32."
  }
}

variable "ssh_public_key_path" {
  description = "Public key generated on bootstrap; NEVER point this at a private key."
  type        = string
  default     = "/home/ubuntu/.ssh/quickbite_lab.pub"
}

variable "control_instance_type" {
  description = "4 GiB recommended for Jenkins and Docker together. This incurs charges."
  type        = string
  default     = "t3.medium"
}

variable "app_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "db_instance_type" {
  description = "2 GiB avoids many MySQL installation/startup memory problems."
  type        = string
  default     = "t3.small"
}
