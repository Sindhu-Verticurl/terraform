provider "aws" {
  region                  = "us-east-2"
  shared_credentials_files= ["~/.aws/credentials"]
}

resource "aws_instance" "terra-app" {
  ami           = "ami-0e83be366243f524a"
  instance_type = "t2.medium"
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_port.id]  # Specify the security group ID(s)
 

  tags = {
    Name = "terra-app-instance"
  }
}

# Rest of your Terraform code remains unchanged


resource "aws_security_group" "allow_port" {
  vpc_id      = aws_vpc.vpc.id
  name        = "allow_port"
  description = "Allow incoming traffic on port 22 and 80"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_Tls"
  }
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "TerraformVPC"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "TerraformAIG"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "TerraformPublicSubnet"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "TerraformPublicRT"
  }
}

resource "aws_route_table_association" "public_subnet_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.16.0/20" 
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false

  tags = {
    Name = "TerraformPrivateSubnet"
  }
}



resource "aws_launch_template" "sindhu" {
  name          = "sindhu-launch-template"
  image_id      = "ami-0e83be366243f524a"  # Replace with your AMI ID
  instance_type = "t2.medium"
  key_name      = "verticurl"      

  vpc_security_group_ids = [aws_security_group.allow_port.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "sindhu-instance"
    }
  }

}

resource "aws_autoscaling_group" "sindhu" {
  desired_capacity     = 2
  max_size             = 4
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.public_subnet.id]
  launch_template {
    id      = aws_launch_template.sindhu.id
    version = "$Latest"
  }

  health_check_type          = "EC2"
  health_check_grace_period  = 300
  force_delete               = true
  wait_for_capacity_timeout  = "0"
  
  tag {
    key                 = "Name"
    value               = "terraform1-app-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_scale_up" {
  name                   = "cpu-scale-up"
  scaling_adjustment    = 1
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 300  # 5 minutes cooldown

  autoscaling_group_name = aws_autoscaling_group.sindhu.name
}

resource "aws_autoscaling_policy" "cpu_scale_down" {
  name                   = "cpu-scale-down"
  scaling_adjustment    = -1
  adjustment_type       = "ChangeInCapacity"
  cooldown              = 300  # 5 minutes cooldown

  autoscaling_group_name = aws_autoscaling_group.sindhu.name
}

