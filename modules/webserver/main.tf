/*Similarly we can create new security group as demonstrated 
in the commented block below */
/*resource "aws_security_group" "myapp-sg" {
  vpc_id = var.vpc_id
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
  vpc_id = var.vpc_id
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
    values = [var.image_name]
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

/* We indicate to Terraform and AWS where the 
pre-created public key is located on our local server*/
resource "aws_key_pair" "ssh-key" {
  key_name = "server-key"
  public_key = var.public_key_location
}

# Create an EC2 instance
resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type 
  
  subnet_id = var.subnet_id
  vpc_security_group_ids = [aws_default_security_group.myapp-default-sg.id]
  availability_zone = var.avail_zone #redundant as subnet is in that same avail zone
  
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh-key.key_name

  # user_data_replace_on_change = true
  # user_data = file("./modules/webserver/entry-script.sh")

  /* Provide host and credentials for Terraform to
   log in the EC2 instance */
  connection {
    type = "ssh"
    host = self.public_ip
    user = "ec2-user"
    private_key = var.private_key_location
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
    source = "./modules/webserver/entry-script.sh"
    destination = "./entry-script-on-EC2.sh"
  }
 
  /* Terraform runs script from local to the remote EC2 instance */
  provisioner "remote-exec" {
    script = "./modules/webserver/entry-script.sh"
    
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
