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

variable "s3_path" {
  default = "data/customer_database/customer_csv/dataload=20230220"
}