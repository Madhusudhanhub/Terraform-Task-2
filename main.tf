terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

# Security Groups
resource "aws_security_group" "web_sg_east" {
  # … other args …

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "web_sg_west" {
  provider    = aws.west
  name        = "web-sg-west"
  description = "Allow SSH & HTTP (us-west-2)"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Optional: Dynamic AMI via SSM
data "aws_ssm_parameter" "ubuntu_ami_east" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

data "aws_ssm_parameter" "ubuntu_ami_west" {
  provider = aws.west
  name     = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# EC2 Instances
resource "aws_instance" "east_server" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami_east.value
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_east.id]
  user_data              = <<-EOF
    #!/bin/bash
    apt-get update -y && apt-get install -y nginx
    systemctl enable nginx && systemctl start nginx
  EOF
  tags                   = { Name = "web-east" }
}

resource "aws_instance" "west_server" {
  provider               = aws.west
  ami                    = data.aws_ssm_parameter.ubuntu_ami_west.value
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg_west.id]
  user_data              = <<-EOF
    #!/bin/bash
    apt-get update -y && apt-get install -y nginx
    systemctl enable nginx && systemctl start nginx
  EOF
  tags                   = { Name = "web-west" }
}
