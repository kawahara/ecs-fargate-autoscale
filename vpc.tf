resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "my-sample-app-vpc-${terraform.workspace}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "my-sample-app-${terraform.workspace}"
  }
}

resource "aws_subnet" "pub_1" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.vpc.az1
  cidr_block        = var.vpc.pub_1_cidr

  tags = {
    Name = "my-sample-app-pub-1-${terraform.workspace}"
  }
}

resource "aws_subnet" "pub_2" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.vpc.az2
  cidr_block        = var.vpc.pub_2_cidr

  tags = {
    Name = "my-sample-app-pub-2-${terraform.workspace}"
  }
}

resource "aws_subnet" "pri_1" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.vpc.az1
  cidr_block        = var.vpc.pri_1_cidr

  tags = {
    Name = "my-sample-app-pri-1-${terraform.workspace}"
  }
}

resource "aws_subnet" "pri_2" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = var.vpc.az2
  cidr_block        = var.vpc.pri_2_cidr

  tags = {
    Name = "my-sample-app-pri-2-${terraform.workspace}"
  }
}

resource "aws_eip" "nat_gateway" {
  vpc = true

  tags = {
    Name = "my-sample-app-${terraform.workspace}"
  }
}

resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.pub_1.id

  tags = {
    Name = "my-sample-app-${terraform.workspace}"
  }
}

resource "aws_route_table" "pub_route" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "my-sample-app-pub-${terraform.workspace}"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "pri_route" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "my-sample-app-pri-${terraform.workspace}"
  }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private.id
  }
}


resource "aws_route_table_association" "pub_1" {
  subnet_id      = aws_subnet.pub_1.id
  route_table_id = aws_route_table.pub_route.id
}

resource "aws_route_table_association" "pub_2" {
  subnet_id      = aws_subnet.pub_2.id
  route_table_id = aws_route_table.pub_route.id
}

resource "aws_route_table_association" "pri_1" {
  subnet_id      = aws_subnet.pri_1.id
  route_table_id = aws_route_table.pri_route.id
}

resource "aws_route_table_association" "pri_2" {
  subnet_id      = aws_subnet.pri_2.id
  route_table_id = aws_route_table.pri_route.id
}

