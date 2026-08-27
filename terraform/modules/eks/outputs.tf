output "cluster_name" {
  value = aws_eks_cluster.petclinic.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.petclinic.endpoint
}

output "oidc_issuer_url" {
  value = aws_eks_cluster.petclinic.identity[0].oidc[0].issuer
}