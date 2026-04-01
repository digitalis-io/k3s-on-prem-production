output "server_public_ips" {
  description = "Map of server node names to public IPv4 addresses"
  value       = { for s in exoscale_compute_instance.server : s.name => s.public_ip_address }
}

output "server_private_ips" {
  description = "Map of server node names to private IPs. Empty when create_network is false."
  value       = var.create_network ? { for s in exoscale_compute_instance.server : s.name => tolist(s.network_interface)[0].ip_address } : {}
}

output "agent_public_ips" {
  description = "Map of agent node names to public IPv4 addresses"
  value       = { for s in exoscale_compute_instance.agent : s.name => s.public_ip_address }
}

output "agent_private_ips" {
  description = "Map of agent node names to private IPs. Empty when create_network is false."
  value       = var.create_network ? { for s in exoscale_compute_instance.agent : s.name => tolist(s.network_interface)[0].ip_address } : {}
}

output "k3s_token" {
  description = "k3s cluster token"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "network_id" {
  description = "ID of the Exoscale private network. Null when create_network is false."
  value       = var.create_network ? exoscale_private_network.cluster[0].id : null
}

output "security_group_id" {
  description = "ID of the cluster security group"
  value       = exoscale_security_group.cluster.id
}

output "ansible_inventory" {
  description = "Ansible inventory in YAML format, matching inventory-k3s.yml structure"
  sensitive   = true
  value = templatefile("${path.module}/templates/inventory.yaml.tftpl", {
    servers                      = exoscale_compute_instance.server
    agents                       = exoscale_compute_instance.agent
    create_network               = var.create_network
    private_network_cidr         = var.private_network_cidr
    kubevip_vip_address          = var.kubevip_vip_address
    vault_k3s_cluster_secret     = base64encode(random_password.k3s_cluster_secret.result)
    vault_k3s_encryption_secret  = base64encode(random_password.k3s_encryption_secret.result)
    vault_falco_sidekick_slack   = base64encode(random_password.falco_sidekick_slack.result)
  })
}
