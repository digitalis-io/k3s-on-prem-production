resource "hcloud_server" "server" {
  count        = var.server_count
  name         = "${var.cluster_name}-server-${count.index + 1}"
  server_type  = var.server_type
  location     = var.location
  image        = var.image
  ssh_keys     = local.ssh_key_ids
  firewall_ids = [hcloud_firewall.cluster.id]

  user_data = templatefile("${path.module}/templates/node.yaml.tftpl", {})

  labels = merge({
    cluster = var.cluster_name
    role    = "server"
  }, var.extra_labels)

  depends_on = [hcloud_network_subnet.cluster]
}

resource "hcloud_server_network" "server" {
  count      = var.create_network ? var.server_count : 0
  server_id  = hcloud_server.server[count.index].id
  network_id = hcloud_network.cluster[0].id
  ip         = local.server_ips[count.index]

  depends_on = [hcloud_network_subnet.cluster]
}
