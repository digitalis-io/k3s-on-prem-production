resource "exoscale_ssh_key" "k3s_cluster_key" {
  count      = length(var.ssh_public_keys)
  name       = "${var.cluster_name}-ssh-key-${count.index}"
  public_key = var.ssh_public_keys[count.index]
}

locals {
  ssh_key_names = concat(
    exoscale_ssh_key.k3s_cluster_key[*].name,
    var.ssh_key_name != "" ? [var.ssh_key_name] : [],
  )
}

resource "exoscale_compute_instance" "server" {
  count              = var.server_count
  zone               = var.zone
  name               = "${var.cluster_name}-server-${count.index + 1}"
  type               = var.server_type
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
      ip_address = local.server_ips[count.index]
    }
  }

  labels = merge({
    cluster = var.cluster_name
    role    = "server"
  }, var.extra_labels)

  depends_on = [exoscale_private_network.cluster]
}
