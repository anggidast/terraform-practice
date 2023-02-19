variable "az" {
  description = "availability_zone"
  default = "us-west-2a"
}

variable "private_ip" {
  description = "network interface private ip"
  default = "10.0.1.50"
}

variable "db_password" {
  description = "RDS root user password"
  type        = string
  sensitive   = true
}