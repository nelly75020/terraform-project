/*Create subnet in previously created VPC, subnet cidr_block,
and avail zone of my choice*/
resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = var.vpc_id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
      Name: "${var.env_prefix}-subnet-1"
  }
}

/* Create an internet gateway to allow the app to 
be connected to the internet*/
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = var.vpc_id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

/* Here we are using the default route table created with the vpc 
No need to explicitely create a route association with the subnet
as the subnets are associated with the main route table 
by default */

resource "aws_default_route_table" "myapp-main-rtb" {
  default_route_table_id = var.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-main-rtb"
  }
}
/*The following 2 sections are used to create new route table 
and subnet association to that new route table */

/*resource "aws_route_table" "myapp-rtb" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name = "${var.env_prefix}-rtb"
  }
}*/

/*resource "aws_route_table_association" "myapp-rtba-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-rtb.id
}*/
