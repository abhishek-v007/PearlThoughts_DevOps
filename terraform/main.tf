provider "aws" {
    region = "us-east-1"  # Adjust as needed
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
    vpc_id            = aws_vpc.main.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "us-east-1a"
}

resource "aws_security_group" "ecs_sg" {
    vpc_id = aws_vpc.main.id

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

resource "aws_ecs_cluster" "main" {
    name = "hello-world-cluster"
}

resource "aws_ecs_task_definition" "hello_world" {
    family                   = "hello-world-task"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = 256
    memory                   = 512

    container_definitions = jsonencode([
        {
            name      = "hello-world-container"
            image     = var.docker_image_url
            essential = true
            portMappings = [
                {
                    containerPort = 3000
                    hostPort      = 3000
                }
            ]
        }
    ])
}

resource "aws_ecs_service" "hello_world" {
    name            = "hello-world-service"
    cluster         = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.hello_world.arn
    desired_count   = 1
    launch_type     = "FARGATE"

    network_configuration {
        subnets         = [aws_subnet.subnet.id]
        security_groups = [aws_security_group.ecs_sg.id]
    }

    load_balancer {
        target_group_arn = aws_lb_target_group.main.arn
        container_name   = "hello-world-container"
        container_port   = 3000
    }
}

resource "aws_lb" "main" {
    name               = "hello-world-lb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.ecs_sg.id]
    subnets            = [aws_subnet.subnet.id]
}

resource "aws_lb_target_group" "main" {
    name     = "hello-world-tg"
    port     = 80
    protocol = "HTTP"
    vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.main.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type             = "forward"
        target_group_arn = aws_lb_target_group.main.arn
    }
}
