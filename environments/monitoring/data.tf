### Data sources
# MGMT State
#data "terraform_remote_state" "mgmt" {
#  backend = "s3"
#  config = {
#    region = var.tfstate_region
#    bucket = var.tfstate_bucket
#    key    = "environments/mgmt/terraform.tfstate"
#  }
#}

# Availability zones
data "aws_availability_zones" "aws_azs" {}

# Latest CentOS 7 AMI in the region (needs manual subscription)
#data "aws_ami" "centos7" {
#  most_recent      = true
#  filter {
#    name   = "owner-id"
#    values = ["679593333241"]
#  }

#  filter {
#    name   = "name"
#    values = ["CentOS Linux 7*x86_64*"]
#  }
#}

# Latest Ubuntu AMI in the region (needs manual subscription)
#data "aws_ami" "ubuntu" {
#    most_recent = true
#    filter {
#        name   = "name"
#        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
#    }

#    filter {
#        name = "virtualization-type"
#        values = ["hvm"]
#    }

#    owners = ["099720109477"]
#}

### Handy locals
locals {
  zone_names = data.aws_availability_zones.aws_azs.names
  zone_ids   = data.aws_availability_zones.aws_azs.zone_ids
#  centos_ami = data.aws_ami.centos7.image_id
#  ubuntu_ami = data.aws_ami.ubuntu.image_id
}

# vim:filetype=terraform ts=2 sw=2 et:
