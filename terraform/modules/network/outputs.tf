output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.petclinic.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"

  value = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"

  value = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]
}