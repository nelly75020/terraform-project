/* Declare provider and region where 
to deploy infrastructure */ 
provider "aws" {
  region = "us-west-1"
}

/* Variable declaration,vars are initialized 
in terraform.tfvars file */
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
variable private_key_location {}

/* Create VPC using a cidr block (ip range) 
of my choice */
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
      Name: "${var.env_prefix}-vpc"
  }
}

/*Create subnet in previously created VPC, subnet cidr_block,
and avail zone of my choice*/
resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
      Name: "${var.env_prefix}-subnet-1"
  }
}

/* Create an internet gateway to allow the app to 
be connected to the internet*/
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
as the subnets are associated with the main route table 
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

/* Here we query image data (aws ami)
that will be used to deploy the EC2 instance */
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

/* In the following 2 blocks, we print out the EC2 
instance image ID and the public IP address respectively */
output "aws_ami_id" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

output "ec2_public_ip" {
  value =aws_instance.myapp-server.public_ip
}

/* We indicate to Terraform and AWS where the 
pre-created public key is located on our local server*/
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

  # user_data_replace_on_change = true
  # user_data = file("entry-script.sh")

  /* Provide host and credentials for Terraform to
   log in the EC2 instance */
  connection {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = file(var.private_key_location)
  }

  /* Provisioners are NOT recommended by Terraform.
  Terraform has no idea of the state of scripts or info
  inside an instance or a server it deploys, thus when it 
  plans it would not know whether a command/script
  that is to be run by provisioner in a instance it created
  was successful or not. Best practice is to use a config
  management tool such as Chef, puppet, or ansible. 
  For local file management, use the Hashicorp
  "local" provider INSTEAD of local-exec provisioner. */

  /* Copy script to execute from server where 
  terraform runs to EC2 instance */
  provisioner "file" {
    source = "entry-script.sh"
    destination = "./entry-script-on-EC2.sh"
  }
 
  /* Terraform runs script from local to the remote EC2 instance */
  provisioner "remote-exec" {
    script = "entry-script.sh"
    
  }

  /*Terraform runs script/command on local server */
  provisioner "local-exec" {
    command = "echo ${self.public_ip} > output.txt"
  }
  
/* Use provisioner and inline to execute a series
of commands in the EC2 instance */
  /*provisioner "remote-exec" {
    inline = [
      "export ENV=DEV",
      "mkdir newdir"
    ]
  }*/
  
  tags = {
    Name: "${var.env_prefix}-server" 
  }
}


