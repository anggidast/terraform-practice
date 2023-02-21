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