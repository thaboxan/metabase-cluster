##########################
# Application Load Balancer
##########################
resource "aws_lb" "metabase_alb" {
  name               = "metabase-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  tags = { Name = "metabase-alb" }
}

resource "aws_lb_target_group" "metabase_tg" {
  name        = "metabase-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/api/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = { Name = "metabase-tg" }
}

resource "aws_lb_listener" "metabase_listener" {
  load_balancer_arn = aws_lb.metabase_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.metabase_tg.arn
  }
}

# Add second public subnet for ALB (ALBs require at least 2 subnets)
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.11.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true
  tags = { Name = "metabase-public-subnet-b" }
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

##########################
# Variables
##########################
variable "region" {
  default = "us-east-1"
}

variable "db_username" {
  default = "metabaseuser"
}

variable "db_password" {
  default = "ChangeMe123!"
}

##########################
# Provider
##########################
provider "aws" {
  region = var.region
}

##########################
# VPC and Networking
##########################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "metabase-vpc" }
}

# Public subnet
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  tags = { Name = "metabase-public-subnet-a" }
}

# Private subnets for RDS
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "${var.region}a"
  tags = { Name = "metabase-private-subnet-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = "${var.region}b"
  tags = { Name = "metabase-private-subnet-b" }
}

# Internet Gateway & Route
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

##########################
# Security Groups
##########################
# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "metabase-alb-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
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

  tags = { Name = "metabase-alb-sg" }
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name_prefix = "metabase-ecs-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Metabase port from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "metabase-ecs-sg" }
}

# RDS SG
resource "aws_security_group" "rds_sg" {
  name_prefix = "metabase-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "metabase-rds-sg" }
}

##########################
# RDS PostgreSQL
##########################
resource "aws_db_subnet_group" "db_subnet" {
  name       = "rds-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}

resource "aws_db_instance" "postgres" {
  identifier              = "metabase-db"
  engine                  = "postgres"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  skip_final_snapshot     = true
}

##########################
# ECS Cluster
##########################
resource "aws_ecs_cluster" "metabase_cluster" {
  name = "metabase-cluster"
}

##########################
# ECS IAM Role (simplified approach)
##########################
# Try to use existing role first
data "aws_iam_role" "existing_ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Create role only if it doesn't exist
resource "aws_iam_role" "ecs_task_execution_role" {
  count = try(data.aws_iam_role.existing_ecs_task_execution_role.arn, null) == null ? 1 : 0

  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  count      = try(data.aws_iam_role.existing_ecs_task_execution_role.arn, null) == null ? 1 : 0
  role       = aws_iam_role.ecs_task_execution_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Local value to determine which role ARN to use
locals {
  execution_role_arn = try(data.aws_iam_role.existing_ecs_task_execution_role.arn, aws_iam_role.ecs_task_execution_role[0].arn)
}

##########################
# ECS Task Definition
##########################
resource "aws_ecs_task_definition" "metabase_task" {
  family                   = "metabase-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = local.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = "metabase"
      image     = "metabase/metabase:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "MB_DB_TYPE", value = "postgres" },
        { name = "MB_DB_DBNAME", value = "postgres" },
        { name = "MB_DB_PORT", value = "5432" },
        { name = "MB_DB_USER", value = var.db_username },
        { name = "MB_DB_PASS", value = var.db_password },
        { name = "MB_DB_HOST", value = aws_db_instance.postgres.address }
      ]
    }
  ])
}

##########################
# ECS Service
##########################
resource "aws_ecs_service" "metabase_service" {
  name            = "metabase-service"
  cluster         = aws_ecs_cluster.metabase_cluster.id
  task_definition = aws_ecs_task_definition.metabase_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.metabase_tg.arn
    container_name   = "metabase"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.metabase_listener]
}

##########################
# Outputs
##########################
output "metabase_url" {
  value       = "http://${aws_lb.metabase_alb.dns_name}"
  description = "URL to access Metabase"
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.address
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.metabase_cluster.name
}
