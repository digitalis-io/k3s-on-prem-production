check "ssh_key_provided" {
  assert {
    condition     = var.ssh_key_name != "" || length(var.ssh_public_keys) > 0

    error_message = "Either ssh_key_name or ssh_public_keys must be provided"
  }
}

# ── OS template lookup ──────────────────────────────────
data "exoscale_template" "os" {
  zone = var.zone
  name = var.template
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

# ── Private network (optional) ──────────────────────────
resource "exoscale_private_network" "cluster" {
  count = var.create_network ? 1 : 0
  zone  = var.zone
  name  = "${var.cluster_name}-network"

  netmask  = cidrnetmask(var.private_network_cidr)
  start_ip = cidrhost(var.private_network_cidr, 10)
  end_ip   = cidrhost(var.private_network_cidr, 254)
}

# ── Static IPs for deterministic addressing ─────────────
locals {
  server_ips = var.create_network ? [for i in range(var.server_count) : cidrhost(var.private_network_cidr, 10 + i)] : []
  agent_ips  = var.create_network ? [for i in range(var.agent_count) : cidrhost(var.private_network_cidr, 100 + i)] : []
}

# ── Security group (firewall) ────────────────────────────
resource "exoscale_security_group" "cluster" {
  name = "${var.cluster_name}-sg"
}

# SSH
resource "exoscale_security_group_rule" "ssh" {
  count             = length(var.ssh_allowed_cidrs)
  security_group_id = exoscale_security_group.cluster.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 22
  end_port          = 22
  cidr              = var.ssh_allowed_cidrs[count.index]
  description       = "Allow SSH"
}

# k3s API
resource "exoscale_security_group_rule" "k3s_api" {
  count             = length(var.k3s_api_allowed_cidrs)
  security_group_id = exoscale_security_group.cluster.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 6443
  end_port          = 6443
  cidr              = var.k3s_api_allowed_cidrs[count.index]
  description       = "Allow k3s API"
}

resource "exoscale_security_group_rule" "wireguard" {
  security_group_id      = exoscale_security_group.cluster.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 51820
  end_port               = 51821
  user_security_group_id = exoscale_security_group.cluster.id
  description            = "Allow WireGuard within cluster"
}

# Inter-node rules (only when private network is enabled)
resource "exoscale_security_group_rule" "internode_tcp" {
  count                  = var.create_network ? 1 : 0
  security_group_id      = exoscale_security_group.cluster.id
  type                   = "INGRESS"
  protocol               = "TCP"
  start_port             = 1
  end_port               = 65535
  user_security_group_id = exoscale_security_group.cluster.id
  description            = "Allow all TCP within cluster"
}

resource "exoscale_security_group_rule" "internode_udp" {
  count                  = var.create_network ? 1 : 0
  security_group_id      = exoscale_security_group.cluster.id
  type                   = "INGRESS"
  protocol               = "UDP"
  start_port             = 1
  end_port               = 65535
  user_security_group_id = exoscale_security_group.cluster.id
  description            = "Allow all UDP within cluster"
}

resource "exoscale_security_group_rule" "internode_icmp" {
  count                  = var.create_network ? 1 : 0
  security_group_id      = exoscale_security_group.cluster.id
  type                   = "INGRESS"
  protocol               = "ICMP"
  icmp_type              = 8
  icmp_code              = 0
  user_security_group_id = exoscale_security_group.cluster.id
  description            = "Allow ICMP within cluster"
}

# NodePort services
resource "exoscale_security_group_rule" "nodeport" {
  count             = length(var.nodeport_allowed_cidrs)
  security_group_id = exoscale_security_group.cluster.id
  type              = "INGRESS"
  protocol          = "TCP"
  start_port        = 30000
  end_port          = 32767
  cidr              = var.nodeport_allowed_cidrs[count.index]
  description       = "Allow NodePort services"
}

# User-defined extra rules
resource "exoscale_security_group_rule" "extra" {
  count                  = length(var.extra_security_group_rules)
  security_group_id      = exoscale_security_group.cluster.id
  type                   = try(var.extra_security_group_rules[count.index].type, "INGRESS")
  protocol               = var.extra_security_group_rules[count.index].protocol
  start_port             = var.extra_security_group_rules[count.index].start_port
  end_port               = var.extra_security_group_rules[count.index].end_port
  cidr                   = var.extra_security_group_rules[count.index].cidr
  user_security_group_id = var.extra_security_group_rules[count.index].user_security_group_id
  description            = var.extra_security_group_rules[count.index].description
}
