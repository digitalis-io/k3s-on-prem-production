output "server_public_ips" {
  description = "Map of server node names to public IPv4 addresses"
  value       = { for s in aws_instance.server : s.tags["Name"] => s.public_ip }
}

output "server_private_ips" {
  description = "Map of server node names to private IPs. Empty when create_network is false."
  value       = var.create_network ? { for s in aws_instance.server : s.tags["Name"] => s.private_ip } : {}
}

output "agent_public_ips" {
  description = "Map of agent node names to public IPv4 addresses"
  value       = { for s in aws_instance.agent : s.tags["Name"] => s.public_ip }
}

output "agent_private_ips" {
  description = "Map of agent node names to private IPs. Empty when create_network is false."
  value       = var.create_network ? { for s in aws_instance.agent : s.tags["Name"] => s.private_ip } : {}
}

output "k3s_token" {
  description = "k3s cluster token"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "network_id" {
  description = "ID of the AWS VPC. Null when create_network is false."
  value       = var.create_network ? aws_vpc.cluster[0].id : null
}

output "security_group_id" {
  description = "ID of the cluster security group"
  value       = aws_security_group.cluster.id
}

output "ansible_inventory" {
  description = "Ansible inventory in YAML format, matching inventory-k3s.yml structure"
  sensitive   = true
  value = templatefile("${path.module}/templates/inventory.yaml.tftpl", {
    servers                     = aws_instance.server
    agents                      = aws_instance.agent
    create_network              = var.create_network
    private_network_cidr        = var.private_network_cidr
    kubevip_vip_address         = var.kubevip_vip_address
    kubevip_external_ip_range   = coalesce(var.kubevip_external_ip_range, join(",", [for a in aws_instance.agent : "${a.public_ip}/32"]))
    kubevip_internal_ip_range   = var.create_network ? coalesce(var.kubevip_internal_ip_range, join(",", [for a in aws_instance.agent : "${a.private_ip}/32"])) : ""
    vault_k3s_cluster_secret    = base64encode(random_password.k3s_cluster_secret.result)
    vault_k3s_encryption_secret = base64encode(random_password.k3s_encryption_secret.result)
    vault_falco_sidekick_slack  = base64encode(random_password.falco_sidekick_slack.result)
  })
}
