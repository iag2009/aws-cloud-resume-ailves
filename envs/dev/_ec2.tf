/* 
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default = "172.31.0.0/16"
}
variable "public_subnets" {
  type        = list(string)
  description = "Available cidr blocks for public subnets."
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}
variable "private_subnets" {
  type        = list(string)
  description = "Available cidr blocks for private subnets."
  default = ["172.31.128.0/20", "172.31.144.0/20", "172.31.160.0/20"]
}
variable "aws_ami" {
  description = "Depends on location"
  type        = string
  default     = "ami-01e7ca2ef94a0ae86"
}
variable "instance_name" {
  description = "Value of the Name tag for the EC2 instance"
  type        = string
  default     = "ailves_instance"
}
variable "sqs" {
  type = object({
    name   = string
    enable = bool
  })
  default = ({
    name   = "sqs_service"
    enable = true
  })
}


resource "aws_instance" "sqs" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  # key_name               = "ailves_da_aws_${var.region}"
  vpc_security_group_ids = [aws_security_group.sqs[count.index].id]
  subnet_id              = data.aws_subnet.selected.id
  count                  = var.sqs.enable ? 1 : 0
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.solution}-${var.project}"
  }
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "sqs" {
  name        = "sqs-ec2-${var.region}"
  description = "sqs-ec2-Sec-Group"
  count       = var.sqs.enable ? 1 : 0
  vpc_id      = data.aws_vpc.selected.id
  tags = {
    Name = "${var.solution}-${var.project}"
  }
}

resource "aws_security_group_rule" "sqs" {
  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "tcp"
  cidr_blocks = [
    var.vpc_cidr
  ]
  security_group_id = aws_security_group.sqs[count.index].id
  count             = var.sqs.enable ? 1 : 0
  depends_on = [
    aws_security_group.sqs
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "selected" {
  cidr_block = var.vpc_cidr
}
data "aws_subnet" "selected" {
  cidr_block = var.private_subnets[0]
}
*/