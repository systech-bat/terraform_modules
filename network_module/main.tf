provider "aws" {
  region = "eu-north-1"
}

#------------------------- VPC & IGW

data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-vpc"
  }
  }

resource "aws_internet_gateway" "main_gate1" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-igw"
  }
}

#---------------------------- Pub Subs & Routs

resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.public_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-${count.index +1}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gate1.id
    }
    tags = {
      Name = "${var.env}-route-public-subnets"
    }
  }

  resource "aws_route_table_association" "public_route" {
    count = length(aws_subnet.public_subnets[*].id)
    route_table_id = aws_route_table.public_route_table.id
    subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
  }

#--------------------------- NAT GW & EIP

resource "aws_eip" "nat_eip" {
  count = length(var.private_subnet_cidrs)
  vpc      = true
  tags = {
    Name = "${var.env}-nat-eip-${count.index +1}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count = length(var.private_subnet_cidrs)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id = element(aws_subnet.public_subnets[*].id, count.index)
  tags = {
    Name = "${var.env}-nat-gw-${count.index +1}"
  }
}



#------------------- Private Subs and Routs



resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.private_subnet_cidrs, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.env}-private-${count.index +1}"
  }
}

resource "aws_route_table" "private_route_table" {
  count = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw[count.index].id
    }
    tags = {
      Name = "${var.env}-route-private-subnets"
    }
  }

  resource "aws_route_table_association" "private_route" {
    count = length(aws_subnet.private_subnets[*].id)
    route_table_id = aws_route_table.private_route_table[count.index].id
    subnet_id = element(aws_subnet.private_subnets[*].id, count.index)
  }
