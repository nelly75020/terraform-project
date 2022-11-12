terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.38.0"
    }
    linode = {
      source  = "linode/linode"
      version = "1.29.4"
    }
  }
}
