module "network" {
  source = "./modules/network"

  vpc_cidr = "10.0.0.0/16"

  public_subnet_1_cidr  = "10.0.1.0/24"
  public_subnet_2_cidr  = "10.0.2.0/24"
  private_subnet_1_cidr = "10.0.11.0/24"
  private_subnet_2_cidr = "10.0.12.0/24"

  availability_zone_1 = "eu-central-1a"
  availability_zone_2 = "eu-central-1b"

  environment = "dev"
}

module "iam" {
  source = "./modules/iam"
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = "petclinic-cluster"
  cluster_role_arn   = module.iam.cluster_role_arn
  node_role_arn      = module.iam.node_role_arn
  private_subnet_ids = module.network.private_subnet_ids
}

module "eks_addons_iam" {
  source = "./modules/eks-addons-iam"

  oidc_issuer_url = module.eks.oidc_issuer_url

  alb_controller_policy_arn = "arn:aws:iam::209211398203:policy/AWSLoadBalancerControllerIAMPolicy"
}