provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Create a VPC
resource "aws_vpc" "ecs_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create a Subnet
resource "aws_subnet" "ecs_subnet" {
  vpc_id     = aws_vpc.ecs_vpc.id
  cidr_block = "10.0.1.0/24"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "ecs_igw" {
  vpc_id = aws_vpc.ecs_vpc.id
}

# Create a Route Table
resource "aws_route_table" "ecs_route_table" {
  vpc_id = aws_vpc.ecs_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ecs_igw.id
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "ecs_subnet_association" {
  subnet_id      = aws_subnet.ecs_subnet.id
  route_table_id = aws_route_table.ecs_route_table.id
}

# Security Group for ECS Instances
resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.ecs_vpc.id

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

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# IAM Role for ECS EC2 Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecs_instance_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for ECS EC2 Instances
resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}


# Create an IAM Instance Profile for ECS EC2 Instances
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ecs_instance_role.name
}


# ECS Launch Configuration
resource "aws_launch_template" "ecs_launch_template" {
  name          = "ecs-launch-template"
  image_id      = data.aws_ami.ecs_ami.id
  instance_type = "t2.micro"

  iam_instance_profile {

    name = aws_iam_instance_profile.ecs_instance_profile.name
  }



  #security_groups = [aws_security_group.ecs_sg.id]
  vpc_security_group_ids = [aws_security_group.ecs_sg.id]


  #user_data = <<-EOF
  #            #!/bin/bash
  #          echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config
  #          EOF


  # User data for ECS cluster
  user_data = base64encode("#!/bin/bash\necho ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.name} >> /etc/ecs/ecs.config")





  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ECS-EC2-Instance"
    }
  }
}




# ECS Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity     = 2
  max_size             = 2
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.ecs_subnet.id]
  #launch_configuration = aws_launch_template.ecs_launch_template.id


  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }


  tag {
    key                 = "Name"
    value               = "ECS-EC2-Instance"
    propagate_at_launch = true
  }
}

# ECS Service Discovery (Optional)
resource "aws_service_discovery_private_dns_namespace" "ecs_service_discovery" {
  name = "ecs.local"
  vpc  = aws_vpc.ecs_vpc.id
}

