resource "aws_db_subnet_group" "db_subnet_group" {
    name = "web-3d-db-subnet-group"
    subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

    tags = {
        Name = "web-3d-db-subnet-group"
    }
}

resource "aws_db_instance" "postgres" {
  identifier = "web-3d-database"
  engine = "postgres"
  engine_version = "16.3"
  instance_class = "db.t4g.micro"
  allocated_storage = 20
  storage_type = "gp3"
  
  db_name = "webstore3d"
  username = "#######"
  password = "########" 
  
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  
  publicly_accessible = false
  skip_final_snapshot = true

  tags = {
    Name = "web-3d-database"
  }
}