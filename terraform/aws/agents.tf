resource "aws_instance" "agent" {
  count                       = var.agent_count
  ami                         = local.ami_id
  instance_type               = var.agent_type
  key_name                    = local.key_name
  vpc_security_group_ids      = [aws_security_group.cluster.id]
  subnet_id                   = local.subnet_id
  associate_public_ip_address = true
  private_ip                  = var.create_network ? local.agent_ips[count.index] : null

  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/templates/node.yaml.tftpl", {})

  tags = merge({
    Name    = "${var.cluster_name}-agent-${count.index + 1}"
    cluster = var.cluster_name
    role    = "agent"
  }, var.extra_labels)

  # Agents must wait for the server to be ready
  depends_on = [aws_instance.server]
}
