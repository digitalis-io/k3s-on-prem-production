resource "aws_instance" "server" {
  count                       = var.server_count
  ami                         = local.ami_id
  instance_type               = var.server_type
  key_name                    = local.key_name
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  subnet_id                   = local.subnet_id
  associate_public_ip_address = true
  private_ip                  = var.create_network ? local.server_ips[count.index] : null

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/node.yaml.tftpl", {})

  tags = merge({
    Name    = "${var.cluster_name}-server-${count.index + 1}"
    cluster = var.cluster_name
    role    = "server"
  }, var.extra_labels)
}
