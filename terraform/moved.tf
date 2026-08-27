moved {
  from = aws_vpc.petclinic
  to   = module.network.aws_vpc.petclinic
}

moved {
  from = aws_subnet.public_1
  to   = module.network.aws_subnet.public_1
}

moved {
  from = aws_subnet.public_2
  to   = module.network.aws_subnet.public_2
}

moved {
  from = aws_subnet.private_1
  to   = module.network.aws_subnet.private_1
}

moved {
  from = aws_subnet.private_2
  to   = module.network.aws_subnet.private_2
}

moved {
  from = aws_internet_gateway.petclinic
  to   = module.network.aws_internet_gateway.petclinic
}

moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}

moved {
  from = aws_route_table_association.public_1
  to   = module.network.aws_route_table_association.public_1
}

moved {
  from = aws_route_table_association.public_2
  to   = module.network.aws_route_table_association.public_2
}

moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}

moved {
  from = aws_nat_gateway.petclinic
  to   = module.network.aws_nat_gateway.petclinic
}

moved {
  from = aws_route_table.private
  to   = module.network.aws_route_table.private
}

moved {
  from = aws_route_table_association.private_1
  to   = module.network.aws_route_table_association.private_1
}

moved {
  from = aws_route_table_association.private_2
  to   = module.network.aws_route_table_association.private_2
}


moved {
  from = aws_eks_cluster.petclinic
  to   = module.eks.aws_eks_cluster.petclinic
}

moved {
  from = aws_eks_node_group.petclinic
  to   = module.eks.aws_eks_node_group.petclinic
}

moved {
  from = aws_iam_openid_connect_provider.eks
  to   = module.eks_addons_iam.aws_iam_openid_connect_provider.eks
}

moved {
  from = aws_iam_role.alb_controller
  to   = module.eks_addons_iam.aws_iam_role.alb_controller
}

moved {
  from = aws_iam_role_policy_attachment.alb_controller
  to   = module.eks_addons_iam.aws_iam_role_policy_attachment.alb_controller
}

moved {
  from = aws_iam_role.eks_cluster
  to   = module.iam.aws_iam_role.eks_cluster
}

moved {
  from = aws_iam_role_policy_attachment.eks_cluster_policy
  to   = module.iam.aws_iam_role_policy_attachment.eks_cluster_policy
}

moved {
  from = aws_iam_role.eks_nodes
  to   = module.iam.aws_iam_role.eks_nodes
}

moved {
  from = aws_iam_role_policy_attachment.eks_worker_node_policy
  to   = module.iam.aws_iam_role_policy_attachment.eks_worker_node_policy
}

moved {
  from = aws_iam_role_policy_attachment.eks_cni_policy
  to   = module.iam.aws_iam_role_policy_attachment.eks_cni_policy
}

moved {
  from = aws_iam_role_policy_attachment.eks_container_registry_policy
  to   = module.iam.aws_iam_role_policy_attachment.eks_container_registry_policy
}