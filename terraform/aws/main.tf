check "ssh_key_provided" {
  assert {
    condition     = var.ssh_key_name != "" || length(var.ssh_public_keys) > 0
    error_message = "Either ssh_key_name or ssh_public_keys must be provided"
  }
}

# ── AMI lookup (fallback to Amazon Linux 2023) ──────────
data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Ubuntu2404-digitalis-hardened-ami-${var.ami_architecture}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = [var.ami_architecture]
  }
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id
}

# ── SSH key pair ─────────────────────────────────────────
resource "aws_key_pair" "k3s_cluster_key" {
  count      = length(var.ssh_public_keys) > 0 ? 1 : 0
  key_name   = "${var.cluster_name}-ssh-key"
  public_key = var.ssh_public_keys[0]

  tags = merge({
    cluster = var.cluster_name
  }, var.extra_labels)
}

locals {
  key_name = length(var.ssh_public_keys) > 0 ? aws_key_pair.k3s_cluster_key[0].key_name : var.ssh_key_name
}

# ── k3s cluster token ───────────────────────────────────
resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

# ── Vault secrets (random, base64-encoded) ──────────────
resource "random_password" "k3s_cluster_secret" {
  length  = 32
  special = false
}

resource "random_password" "k3s_encryption_secret" {
  length  = 32
  special = false
}

resource "random_password" "falco_sidekick_slack" {
  length  = 32
  special = false
}

# ── VPC and subnet (optional) ───────────────────────────
resource "aws_vpc" "cluster" {
  count                = var.create_network ? 1 : 0
  cidr_block           = var.private_network_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge({
    Name    = "${var.cluster_name}-vpc"
    cluster = var.cluster_name
  }, var.extra_labels)
}

resource "aws_internet_gateway" "cluster" {
  count  = var.create_network ? 1 : 0
  vpc_id = aws_vpc.cluster[0].id

  tags = merge({
    Name    = "${var.cluster_name}-igw"
    cluster = var.cluster_name
  }, var.extra_labels)
}

resource "aws_subnet" "cluster" {
  count                   = var.create_network ? 1 : 0
  vpc_id                  = aws_vpc.cluster[0].id
  cidr_block              = var.private_network_cidr
  map_public_ip_on_launch = true

  tags = merge({
    Name    = "${var.cluster_name}-subnet"
    cluster = var.cluster_name
  }, var.extra_labels)
}

resource "aws_route_table" "cluster" {
  count  = var.create_network ? 1 : 0
  vpc_id = aws_vpc.cluster[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster[0].id
  }

  tags = merge({
    Name    = "${var.cluster_name}-rt"
    cluster = var.cluster_name
  }, var.extra_labels)
}

resource "aws_route_table_association" "cluster" {
  count          = var.create_network ? 1 : 0
  subnet_id      = aws_subnet.cluster[0].id
  route_table_id = aws_route_table.cluster[0].id
}

# ── Default VPC lookup (when create_network is false) ───
data "aws_vpc" "default" {
  count   = var.create_network ? 0 : 1
  default = true
}

data "aws_subnets" "default" {
  count = var.create_network ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

locals {
  vpc_id    = var.create_network ? aws_vpc.cluster[0].id : data.aws_vpc.default[0].id
  subnet_id = var.create_network ? aws_subnet.cluster[0].id : data.aws_subnets.default[0].ids[0]
}

# ── Static IPs for deterministic addressing ─────────────
locals {
  server_ips = var.create_network ? [for i in range(var.server_count) : cidrhost(var.private_network_cidr, 10 + i)] : []
  agent_ips  = var.create_network ? [for i in range(var.agent_count) : cidrhost(var.private_network_cidr, 100 + i)] : []
}

# ── Security group ───────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-sg"
  description = "Security group for ${var.cluster_name} k3s cluster"
  vpc_id      = local.vpc_id

  tags = merge({
    Name    = "${var.cluster_name}-sg"
    cluster = var.cluster_name
  }, var.extra_labels)
}

# SSH
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  count             = length(var.ssh_allowed_cidrs)
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidrs[count.index]
  description       = "Allow SSH"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

# k3s API
resource "aws_vpc_security_group_ingress_rule" "k3s_api" {
  count             = length(var.k3s_api_allowed_cidrs)
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
  cidr_ipv4         = var.k3s_api_allowed_cidrs[count.index]
  description       = "Allow k3s API"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

# WireGuard (intra-cluster)
resource "aws_vpc_security_group_ingress_rule" "wireguard" {
  security_group_id            = aws_security_group.cluster.id
  ip_protocol                  = "udp"
  from_port                    = 51820
  to_port                      = 51821
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow WireGuard within cluster"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

# Inter-node rules (only when private network is enabled)
resource "aws_vpc_security_group_ingress_rule" "internode_tcp" {
  count                        = var.create_network ? 1 : 0
  security_group_id            = aws_security_group.cluster.id
  ip_protocol                  = "tcp"
  from_port                    = 1
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow all TCP within cluster"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

resource "aws_vpc_security_group_ingress_rule" "internode_udp" {
  count                        = var.create_network ? 1 : 0
  security_group_id            = aws_security_group.cluster.id
  ip_protocol                  = "udp"
  from_port                    = 1
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow all UDP within cluster"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

resource "aws_vpc_security_group_ingress_rule" "internode_icmp" {
  count                        = var.create_network ? 1 : 0
  security_group_id            = aws_security_group.cluster.id
  ip_protocol                  = "icmp"
  from_port                    = 8
  to_port                      = 0
  referenced_security_group_id = aws_security_group.cluster.id
  description                  = "Allow ICMP within cluster"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

# NodePort services
resource "aws_vpc_security_group_ingress_rule" "nodeport" {
  count             = length(var.nodeport_allowed_cidrs)
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = "tcp"
  from_port         = 30000
  to_port           = 32767
  cidr_ipv4         = var.nodeport_allowed_cidrs[count.index]
  description       = "Allow NodePort services"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

# Egress: allow all outbound
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic"

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}

# User-defined extra rules
resource "aws_vpc_security_group_ingress_rule" "extra" {
  count             = length(var.extra_security_group_rules)
  security_group_id = aws_security_group.cluster.id
  ip_protocol       = var.extra_security_group_rules[count.index].protocol
  from_port         = var.extra_security_group_rules[count.index].start_port
  to_port           = var.extra_security_group_rules[count.index].end_port
  cidr_ipv4         = var.extra_security_group_rules[count.index].cidr
  description       = var.extra_security_group_rules[count.index].description

  tags = merge({ cluster = var.cluster_name }, var.extra_labels)
}
