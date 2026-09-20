resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "web-3d-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id = aws_subnet.public_a.id

  tags = {
    Name = "web-3d-nat-gateway"
  }
}

resource "aws_route" "private_internet_access" {
  route_table_id = aws_route_table.private.id 
  
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.main.id
}