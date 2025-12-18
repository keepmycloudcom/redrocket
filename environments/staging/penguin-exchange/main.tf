### General blurb
terraform {
  required_version =  "1.5.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.91.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
}

provider "random" {
}

provider "null" {
}

# vim:filetype=terraform ts=2 sw=2 et:
