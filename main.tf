
# Data Source for Availability Zones
data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.tags["Name"]}.vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.tags["Name"]}.igw"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.tags["Name"]}.public-subnet-${count.index + 1}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = element(["10.0.3.0/24", "10.0.4.0/24"], count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.tags["Name"]}.private-subnet-${count.index + 1}"
  }
}

# Create Security Group
resource "aws_security_group" "default" {
  vpc_id = aws_vpc.main.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = var.tags
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.tags["Name"]}.eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "${var.tags["Name"]}.nat"
  }
}

# Create Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.tags["Name"]}.pub-route"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count         = 2
  subnet_id     = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Create Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = {
    Name = "${var.tags["Name"]}.pvt-route"
  }
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Create EC2 Instance
resource "aws_instance" "my_instance" {
  ami                    = "ami-0892a9c01908fafd1"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.default.id]
  tags = {
    Name = "${var.tags["Name"]}.ec2"
    environment = "dev"
  }
}

# Create Application Load Balancer (ALB)
resource "aws_lb" "main" {
  name               = "${var.tags["Name"]}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.default.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.tags["Name"]}.alb"
  }
}

# Create Target Group for ALB
resource "aws_lb_target_group" "main" {
  name     = "${var.tags["Name"]}-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "${var.tags["Name"]}.target-group"
  }
}

# Create ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name = "${var.tags["Name"]}.listener"
  }
}

# Attach EC2 Instance to Target Group
resource "aws_lb_target_group_attachment" "instance" {
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = aws_instance.my_instance.id
  port             = 80
}

# Create RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.tags["Name"]}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

# Create RDS Instance
resource "aws_db_instance" "main" {
  allocated_storage      = 20
  engine                 = "mysql"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "password"
   engine_version         = "8.0.35"
 parameter_group_name = "default.mysql8.0"
  db_subnet_group_name   = aws_db_subnet_group.main.id
  vpc_security_group_ids = [aws_security_group.default.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}
# Define the S3 bucket for Terraform state storage
resource "aws_s3_bucket" "terraform_state" {
  bucket = "anisha-bucket"  
 # region = "ap-southeast-2"
  acl    = "private"
  force_destroy = true

tags = {
    Name = "${var.tags["Name"]}.s3-state"
  }
}

# Define the DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = {
    Name = "${var.tags["Name"]}.dynamodb-locks"
  }
}




