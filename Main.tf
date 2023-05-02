### provider
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
  region     = "us-east-2"
  access_key = "************************"
  secret_key = "************************"
}

### tf_cloud
terraform {
  cloud {
    organization = "my-lab"

    workspaces {
      name = "example-workspace"
    }
  }
}

### VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name = "my_vpc"
  }
}

### subnets
# public_subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id # binding to vpc
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = "true" # White IP

  tags = {
    Name = "public_subnet"
  }
}

# private_subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id # binding to vpc
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = "false" # No white IP

  tags = {
    Name = "private_subnet"
  }
}

### Route table
# create RT for private subnet
resource "aws_route_table" "rt_for_private_subnet" {
  vpc_id = aws_vpc.my_vpc.id # binding to vpc

  tags = {
    Name = "rt_for_private_subnet"
  }
}

# binding RT to private_subnet
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.rt_for_private_subnet.id
}

# add route to NAT gw
resource "aws_route" "private_route-1" {
  route_table_id         = aws_route_table.rt_for_private_subnet.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.my_nat_gw.id
}

# create RT for public subnet
resource "aws_route_table" "rt_for_public_subnet" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "rt_for_public_subnet"
  }
}

# binding RT to public_subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rt_for_public_subnet.id
}

# add route to Internet_gw
resource "aws_route" "public_route-1" {
  route_table_id         = aws_route_table.rt_for_public_subnet.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.custom_internet_gw.id
}

### Internet GW
resource "aws_internet_gateway" "custom_internet_gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "custom_internet_gw"
  }
}

### NAT GW
resource "aws_nat_gateway" "my_nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "my_nat_gw"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

### Sec_groups
# public
resource "aws_security_group" "public_sec_group" {
  name        = "SG_for_public_subnet"
  description = "SG_for_public_subnet"
  vpc_id      = aws_vpc.my_vpc.id
  
  tags = {
    Name = "SG_for_public_subnet"
  }
}

resource "aws_security_group_rule" "public-web-access" {
  type = "ingress"
  security_group_id = "${aws_security_group.public_sec_group.id}"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

resource "aws_security_group_rule" "public-icmp-access" {
  type = "ingress"
  security_group_id = "${aws_security_group.public_sec_group.id}"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

resource "aws_security_group_rule" "public-ssh-access-from-my-pc" {
  type = "ingress"
  security_group_id = "${aws_security_group.public_sec_group.id}"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # please change this CIDR
  }

resource "aws_security_group_rule" "public-egress-to-all" {
  type = "egress"
  security_group_id = "${aws_security_group.public_sec_group.id}"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

# Private
resource "aws_security_group" "private_sec_group" {
  name        = "SG_for_private_subnet"
  description = "SG_for_private_subnet"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "SG_for_private_subnet"
  }
}

resource "aws_security_group_rule" "private-ssh-access-from-public-subnet" {
  type = "ingress"
  security_group_id = "${aws_security_group.private_sec_group.id}"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

resource "aws_security_group_rule" "private-icmp-access" {
  type = "ingress"
  security_group_id = "${aws_security_group.private_sec_group.id}"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.0.1.0/24"]
  }

resource "aws_security_group_rule" "private-mysql-access" {
  type = "ingress"
  security_group_id = "${aws_security_group.private_sec_group.id}"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

resource "aws_security_group_rule" "private-egress-to-all" {
  type = "egress"
  security_group_id = "${aws_security_group.private_sec_group.id}"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

# web server
resource "aws_instance" "web" {
  for_each = {
    "web" = "ami-00eeedc4036573771"
  }

  ami           = each.value
  instance_type = "t2.micro"
  key_name      = "awskey"
  vpc_security_group_ids = [aws_security_group.public_sec_group.id]
  user_data              = file("userdata1.tpl")
  subnet_id = aws_subnet.public_subnet.id

  tags = {
    Name = "My ${each.key}"
  }
}

# DB server
resource "aws_instance" "db" {
  for_each = {
    "db" = "ami-00eeedc4036573771"
  }

  ami                    = each.value
  instance_type          = "t2.micro"
  key_name               = "awskey"
  vpc_security_group_ids = [aws_security_group.private_sec_group.id]
  user_data              = file("userdata2.tpl")

  subnet_id = aws_subnet.private_subnet.id

  tags = {
    Name = "My ${each.key}"
  }
}
