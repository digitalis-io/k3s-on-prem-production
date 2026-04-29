resource "exoscale_compute_instance" "agent" {
  count              = var.agent_count
  zone               = var.zone
  name               = "${var.cluster_name}-agent-${count.index + 1}"
  type               = var.agent_type
  template_id        = data.exoscale_template.os.id
  disk_size          = var.disk_size
  ssh_keys           = local.ssh_key_names
  security_group_ids = [exoscale_security_group.cluster.id]

  user_data = templatefile("${path.module}/templates/node.yaml.tftpl", {
  })

  dynamic "network_interface" {
    for_each = var.create_network ? [1] : []
    content {
      network_id = exoscale_private_network.cluster[0].id
      ip_address = local.agent_ips[count.index]
    }
  }

  labels = merge({
    cluster = var.cluster_name
    role    = "agent"
  }, var.extra_labels)

  # Agents must wait for the server to be ready
  depends_on = [exoscale_compute_instance.server]
}
