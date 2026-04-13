output "server_public_ips" {
  description = "Map of server node names to public IPv4 addresses"
  value       = { for s in hcloud_server.server : s.name => s.ipv4_address }
}

output "server_private_ips" {
  description = "Map of server node names to private IPs. Empty when create_network is false."
  value       = var.create_network ? { for i, s in hcloud_server.server : s.name => hcloud_server_network.server[i].ip } : {}
}

output "agent_public_ips" {
  description = "Map of agent node names to public IPv4 addresses"
  value       = { for s in hcloud_server.agent : s.name => s.ipv4_address }
}

output "agent_private_ips" {
  description = "Map of agent node names to private IPs. Empty when create_network is false."
  value       = var.create_network ? { for i, s in hcloud_server.agent : s.name => hcloud_server_network.agent[i].ip } : {}
}

output "k3s_token" {
  description = "k3s cluster token"
  value       = random_password.k3s_token.result
  sensitive   = true
}

output "network_id" {
  description = "ID of the Hetzner private network. Null when create_network is false."
  value       = var.create_network ? hcloud_network.cluster[0].id : null
}

output "firewall_id" {
  description = "ID of the cluster firewall"
  value       = hcloud_firewall.cluster.id
}

output "ansible_inventory" {
  description = "Ansible inventory in YAML format, matching inventory-k3s.yml structure"
  sensitive   = true
  value = templatefile("${path.module}/templates/inventory.yaml.tftpl", {
    servers                     = hcloud_server.server
    agents                      = hcloud_server.agent
    server_networks             = hcloud_server_network.server
    agent_networks              = hcloud_server_network.agent
    create_network              = var.create_network
    private_network_cidr        = var.private_network_cidr
    kubevip_vip_address         = var.kubevip_vip_address
    kubevip_external_ip_range   = coalesce(var.kubevip_external_ip_range, join(",", [for a in hcloud_server.agent : "${a.ipv4_address}/32"]))
    kubevip_internal_ip_range   = var.create_network ? coalesce(var.kubevip_internal_ip_range, join(",", [for i, a in hcloud_server.agent : "${hcloud_server_network.agent[i].ip}/32"])) : ""
    vault_k3s_cluster_secret    = base64encode(random_password.k3s_cluster_secret.result)
    vault_k3s_encryption_secret = base64encode(random_password.k3s_encryption_secret.result)
    vault_falco_sidekick_slack  = base64encode(random_password.falco_sidekick_slack.result)
  })
}
