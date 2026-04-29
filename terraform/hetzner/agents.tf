resource "hcloud_server" "agent" {
  count        = var.agent_count
  name         = "${var.cluster_name}-agent-${count.index + 1}"
  server_type  = var.agent_type
  location     = var.location
  image        = var.image
  ssh_keys     = local.ssh_key_ids
  firewall_ids = [hcloud_firewall.cluster.id]

  user_data = templatefile("${path.module}/templates/node.yaml.tftpl", {})

  labels = merge({
    cluster = var.cluster_name
    role    = "agent"
  }, var.extra_labels)

  # Agents must wait for the server to be ready
  depends_on = [hcloud_server.server]
}

resource "hcloud_server_network" "agent" {
  count      = var.create_network ? var.agent_count : 0
  server_id  = hcloud_server.agent[count.index].id
  network_id = hcloud_network.cluster[0].id
  ip         = local.agent_ips[count.index]

  depends_on = [hcloud_network_subnet.cluster]
}
