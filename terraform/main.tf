resource "aws_vpc" "petclinic" {
  cidr_block = var.vpc_cidr

  tags = {
    Name        = "petclinic-vpc"
    Environment = "dev"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.petclinic.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "petclinic-public-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.petclinic.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name        = "petclinic-public-2"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.petclinic.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "eu-central-1a"

  tags = {
    Name        = "petclinic-private-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.petclinic.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "eu-central-1b"

  tags = {
    Name        = "petclinic-private-2"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "petclinic" {
  vpc_id = aws_vpc.petclinic.id

  tags = {
    Name        = "petclinic-igw"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.petclinic.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.petclinic.id
  }

  tags = {
    Name        = "petclinic-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}


resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "petclinic-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "petclinic" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name        = "petclinic-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.petclinic]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.petclinic.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.petclinic.id
  }

  tags = {
    Name        = "petclinic-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_iam_role" "eks_cluster" {
  name = "petclinic-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


resource "aws_eks_cluster" "petclinic" {
  name     = "petclinic-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private_1.id,
      aws_subnet.private_2.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}