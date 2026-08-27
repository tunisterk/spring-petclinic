resource "aws_eks_cluster" "petclinic" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.private_subnet_ids

  }
}


resource "aws_eks_node_group" "petclinic" {
  cluster_name    = aws_eks_cluster.petclinic.name
  node_group_name = "petclinic-nodes"
  node_role_arn   = var.node_role_arn

  subnet_ids     = var.private_subnet_ids
  instance_types = ["c7i-flex.large"]

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }
}

