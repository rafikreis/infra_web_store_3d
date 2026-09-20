resource "aws_ecs_cluster" "main" {
  name = "web-3d-cluster"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "web-3d-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app" {
  family = "web-3d-task"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name = "web-3d-container"
    image = "nginxdemos/hello:latest" 
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort = 80
    }]
  }])
}

resource "aws_ecs_service" "main" {
  name = "web-3d-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count = 2
  launch_type = "FARGATE"

  network_configuration {
    subnets = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups = [aws_security_group.app_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name = "web-3d-container"
    container_port = 80
  }
}