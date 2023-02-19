terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-west-2"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "proj1" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "project 1"
  }
}

# 1.2. create internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.proj1.id
}

# 1.3. create custom route table
resource "aws_route_table" "proj1_route_table" {
  vpc_id = aws_vpc.proj1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "proj1"
  }
}

# 1.4. create a subnet
resource "aws_subnet" "subnet_1" {
  vpc_id            = aws_vpc.proj1.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "proj1-subnet-1"
  }
}

resource "aws_subnet" "subnet_2" {
  vpc_id            = aws_vpc.proj1.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "proj1-subnet-2"
  }
}

# 1.5. associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.proj1_route_table.id
}

# 1.6. create security group to allow port 22, 80, 443 for EC2 instance
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.proj1.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 1.7. create a network interface with an IP in the subnet was created in step 4
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.subnet_1.id
  private_ips     = [var.private_ip]
  security_groups = [aws_security_group.allow_web.id]
}

# 1.8. assign an elastic IP to the network interface in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = var.private_ip
  depends_on = [aws_instance.web_server_instance,
    aws_internet_gateway.gw
  ]
}

# 1.9. create ubuntu server and install/enable apache2
resource "aws_instance" "web_server_instance" {
  ami               = "ami-00712dae9a53f8c15"
  instance_type     = "t2.micro"
  availability_zone = data.aws_availability_zones.available.names[0]
  key_name          = "test-anggi-2"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web_server_nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo this is web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "web-server"
  }
}

# 2.1. create security group to access RDS instance only
resource "aws_security_group" "allow_db" {
  name   = "allow_db"
  vpc_id = aws_vpc.proj1.id

  ingress {
    description     = "Postgres"
    from_port       = "5432"
    to_port         = "5432"
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_web.id]
  }

  tags = {
    Name = "allow db"
  }
}

# 2.2. create subnet group
resource "aws_db_subnet_group" "proj1" {
  name       = "proj1"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name = "db subnet group"
  }
}

# 2.3. create RDS db instance 
resource "aws_db_instance" "rds" {
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "14.1"
  username               = "anggi"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.proj1.name
  vpc_security_group_ids = [aws_security_group.allow_db.id]
  skip_final_snapshot    = true
}

# 3.1. create S3 bucket
resource "aws_s3_bucket" "proj1" {
  bucket = "proj1-bucket-anggi-test"

  tags = {
    Name = "Project 1 bucket"
  }
}

# 3.2. configure S3 ACL
resource "aws_s3_bucket_acl" "acl" {
  bucket = aws_s3_bucket.proj1.id
  acl    = "private"
}

# 3.3. upload file to S3 bucket
resource "aws_s3_object" "object" {
  bucket = aws_s3_bucket.proj1.bucket
  key    = "customer.csv"
  source = "${path.root}/file/test/customer.csv"
}

# 4.1. create IAM role for Glue
resource "aws_iam_role" "glue" {
  name               = "AWSGlueServiceRoleDefault"
  assume_role_policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "glue.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

# 4.2. attach policy to Glue IAM role
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 4.3. add S3 policy for Glue IAM role
resource "aws_iam_role_policy" "my_s3_policy" {
  name = "my_s3_policy"
  role = aws_iam_role.glue.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*"
        ],
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.proj1.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.proj1.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.proj1.bucket}*"
        ]
      }
    ]
  })
}

# 4.4. create Glue data catalog database
resource "aws_glue_catalog_database" "proj1" {
  name = "proj_1_catalog_db"
}

# 4.5. crawl S3 object
resource "aws_glue_crawler" "proj1" {
  database_name = aws_glue_catalog_database.proj1.name
  name          = "customer_data_crawler"
  role          = aws_iam_role.glue.arn

  configuration = jsonencode(
    {
      Grouping = {
        TableGroupingPolicy = "CombineCompatibleSchemas"
      }
      CrawlerOutput = {
        Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      }
      Version = 1
    }
  )

  s3_target {
    path = "s3://${aws_s3_bucket.proj1.bucket}"
  }
}

