resource "aws_security_group" "alb_sg" {
  name = "web-3d-alb-sg"
  description = "Allow HTTP and HTTPS traffic from the internet"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "HTTP from everywhere"
    from_port  = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from everywhere"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-3d-alb-sg"
  }
}

resource "aws_security_group" "app_sg" {
  name = "web-3d-app-sg"
  description = "Allow traffic only from the Load Balancer"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Traffic from ALB"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-3d-app-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name = "web-3d-db-sg"
  description = "Allow traffic only from the Application"
  vpc_id = aws_vpc.main.id

  ingress {
    description= "Traffic from App"
    from_port= 5432
    to_port  = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port= 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-3d-db-sg"
  }
}