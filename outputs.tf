/* In the following 2 blocks, we print out the EC2 
instance image ID and the public IP address respectively */
output "ec2_public_ip" {
  value = module.myapp-server.instance.public_ip
}