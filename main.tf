provider "aws" {
  region = "us-west-1"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
      Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
      Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

/*The following 2 sections are used to create new route table 
and subnet association to that new route table */

/*resource "aws_route_table" "myapp-rtb" {
  vpc_id = aws_vpc.myapp-vpc.id
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


/* Here we are using the default route table created with the vpc 
No need to explicitely create a route association with the subnet
as the subnets are associated with the main (aka default) route table 
by default */

resource "aws_default_route_table" "myapp-main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-main-rtb"
  }
}

/*Similarly we can create new security group as demonstrated 
in the commented block below */
/*resource "aws_security_group" "myapp-sg" {
  vpc_id = aws_vpc.myapp-vpc.id
  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = [var.my_ip]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080  
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0  
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name: "${var.env_prefix}-sg"
  }
}*/


/* We can also use the default security group 
that comes with the vpc resource*/

resource "aws_default_security_group" "myapp-default-sg" {
  vpc_id = aws_vpc.myapp-vpc.id
  ingress {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
    cidr_blocks = [var.my_ip]
  }
  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080  
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0  
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name: "${var.env_prefix}-default-sg"
  }
}

#Query image data (aws ami)
data "aws_ami" "latest-amazon-linux-image" {
  most_recent      = true
  owners           = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-*-x86_64-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value =aws_instance.myapp-server.public_ip
}

resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = file(var.public_key_location)
}

# Create an EC2 instance
resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type 
  
  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_default_security_group.myapp-default-sg.id]
  availability_zone = var.avail_zone #redundant as subnet is in that same avail zone
  
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  user_data_replace_on_change = true
  user_data = file("entry-script.sh")
  
  tags = {
    Name: "${var.env_prefix}-server" 
  }
}


