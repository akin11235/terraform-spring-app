# =============================================================================
# NETWORKING INFRASTRUCTURE
# Create VPC, subnets, gateways, route tables and routing
# =============================================================================

# Virtual Private Cloud - Creates isolated network environment
# =============================================================================
resource "aws_vpc" "main_vpc" {
  # cidr_block = "10.0.0.0/16"
  cidr_block = var.vpc_cidr

  # Enable DNS resolution and hostnames for internal communication
  enable_dns_hostnames = true # Allows instances to get public DNS names
  enable_dns_support   = true # Enables DNS resolution via Amazon DNS server

  tags = {
    Name = "main-vpc-java-app"
  }
  # VPC acts as the container for all our network resources
}


# Internet Gateway - Provides internet access to public subnets
# =============================================================================
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id # Attach to the VPC

  tags = {
    Name = "Main-IGW-java-app"
  }
  # IGW is managed by AWS, horizontally scaled, redundant, and highly available
}


# Public Subnet - Resources here can have direct internet access
# =============================================================================
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0] # Use first available AZ
  map_public_ip_on_launch = true                                           # Automatically assign public IPs to instances

  tags = {
    Name = "public-subnet-java-app"
    Type = "Public"
  }
  # Public subnet is where the EC2 instance will reside.
}

# Second Public Subnet - different AZ
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1] # Second AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-2-java-app"
    Type = "Public"
  }
}



# Private Subnet - No direct internet access, first AZ
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0] # Same AZ as public

  tags = {
    Name = "private_subnet-a-java-app"
    Type = "Private"
  }
  # This subnet will host the RDS database subnet group
}

# Private Subnet - Second AZ
resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1] # Second AZ

  tags = {
    Name = "private_subnet-b-java-app"
    Type = "Private"
  }
}

# =============================================================================
# ROUTING CONFIGURATION
# Control how network traffic flows between subnets and the internet
# =============================================================================

# Public Route Table - Routes traffic from public subnet to internet
resource "aws_route_table" "public_route_table_1" {
  vpc_id = aws_vpc.main_vpc.id

  # Default route: send all traffic (0.0.0.0/0) to Internet Gateway
  route {
    cidr_block = var.public_route_cidr # All destinations
    gateway_id = aws_internet_gateway.main_igw.id
  }
  # This enables bidirectional internet connectivity for public subnet

  tags = {
    Name = "Public-Route-Table-1"
  }
}

# Private Route Table
resource "aws_route_table" "private_route_table_1" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Private-Route-Table-1"
  }
}

# Private Route Table - Uses NAT Gateway for outbound internet access
resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_route_table_1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# Elastic IP for NAT Gateway (must be in a VPC scope)
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip-java-app"
  }
}

# Create NAT Gateway in the Public Subnet
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "nat-gateway-java-app"
  }

  depends_on = [aws_internet_gateway.main_igw] # Ensure IGW exists first
}


# Associate Route Tables with Subnets
# Public subnet association
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table_1.id
}

# Private subnet A association
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = aws_subnet.private_subnet_a.id
  route_table_id = aws_route_table.private_route_table_1.id
}

# Private subnet B association
resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = aws_subnet.private_subnet_b.id
  route_table_id = aws_route_table.private_route_table_1.id
}
