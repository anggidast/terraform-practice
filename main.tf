data "aws_availability_zones" "available" {
  state = "available"
}

# 1.1. create VPC
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