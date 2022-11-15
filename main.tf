/* Declare provider and region where 
to deploy infrastructure */ 
provider "aws" {
  region = "us-west-1"
}

/* Create VPC using a cidr block (ip range) 
of my choice */
resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
      Name: "${var.env_prefix}-vpc"
  }
}

module "myapp-subnet" {
  source = "./modules/subnet"
  subnet_cidr_block = var.subnet_cidr_block
  avail_zone = var.avail_zone
  vpc_id = aws_vpc.myapp-vpc.id
  env_prefix = var.env_prefix 
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
}

module "myapp-server" {
  source ="./modules/webserver"
  vpc_id = aws_vpc.myapp-vpc.id
  my_ip = var.my_ip
  env_prefix = var.env_prefix
  image_name = var.image_name
  public_key_location = file(var.public_key_location)
  instance_type = var.instance_type
  subnet_id = module.myapp-subnet.subnet.id
  avail_zone = var.avail_zone
  private_key_location = file(var.private_key_location)
}

