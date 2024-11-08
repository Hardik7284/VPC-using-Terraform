resource "aws_vpc" "myvpc" {
  cidr_block       = "100.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "MY-VPC"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "100.0.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "PUBLIC_SUBNET"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "100.0.2.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "Private-Subnet"
  }
}

resource "aws_eip" "eip" {
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "IGW"
  }
}
resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "NAT gw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public-Route"
  }
}
resource "aws_route_table_association" "pub-a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public-route.id
}


resource "aws_route_table" "private-route" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "Private-Route"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private-route.id
}

resource "aws_security_group" "mysg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.mysg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  security_group_id = aws_security_group.mysg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 3306
  ip_protocol       = "tcp"
  to_port           = 3306
}
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.mysg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.mysg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
# EC2 INSTANCE

resource "aws_instance" "web" {
  ami                         = "ami-022ce6f32988af5fa"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.mysg.id]
  associate_public_ip_address = "true"
  key_name                    = "project"
  user_data                   = <<-EOF
            #!/bin/bash
            yum install httpd -y
            systemctl restart httpd
            systemctl enable httpd
            echo "<center><h1>My First Terraform Project</h1></center>" >> /var/www/html/index.html
  EOF
  tags = {
    Name = "WebServer"
  }
}
resource "aws_instance" "sql" {
  ami                         = "ami-022ce6f32988af5fa"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.mysg.id]
  associate_public_ip_address = "false"
  key_name                    = "project"
  user_data                   = <<-EOF
    #!/bin/bash
    dnf install mariadb-server -y
    systemctl start mariadb.service
    systemctl enable mariadb.service
  EOF
  tags = {
    Name = "SQL-private"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "project"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCPGjlfemzLUsMV3nK+PVgbqodjYLCqVIlj+UZD/HqIqR5yQB7zAQrk0S/dWWv6gr06o2wDRDOyVsyi/XkoBiM9b/+eMAV8bmKCgfaQFpQOfAxU91UGin5+BV9DQ78D3+V2sdn5+X/uitzoPw0g3pFgkRU2IlclZRShghNjNw3PHzPIFt9C+XgOn3V4Bq5uRDIyvYJp0sO2OtTT3nzLs4f8hwz34HUVC/JkgwxPLjBY+byErkQnuXDx0rxwTWHdwRqp4q87j3VU/q0CgkHZw6bwRrS2Biq91rK/+i7U5EONR94BdrCwe2PegB/xbuvC2DcG77Re/fDxgHxtPTyG28NV kp"
}
