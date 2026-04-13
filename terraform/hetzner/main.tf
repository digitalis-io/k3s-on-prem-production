check "ssh_key_provided" {
  assert {
    condition     = var.ssh_key_name != "" || length(var.ssh_public_keys) > 0
    error_message = "Either ssh_key_name or ssh_public_keys must be provided"
  }
}

# ── SSH keys ────────────────────────────────────────────
resource "hcloud_ssh_key" "k3s_cluster_key" {
  count      = length(var.ssh_public_keys)
  name       = "${var.cluster_name}-ssh-key-${count.index}"
  public_key = var.ssh_public_keys[count.index]
}

# ── Resolve pre-existing SSH key by name ────────────────
data "hcloud_ssh_key" "existing" {
  count = var.ssh_key_name != "" ? 1 : 0
  name  = var.ssh_key_name
}

locals {
  ssh_key_ids = concat(
    hcloud_ssh_key.k3s_cluster_key[*].id,
    var.ssh_key_name != "" ? [data.hcloud_ssh_key.existing[0].id] : [],
  )
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
resource "hcloud_network" "cluster" {
  count    = var.create_network ? 1 : 0
  name     = "${var.cluster_name}-network"
  ip_range = var.private_network_cidr
}

resource "hcloud_network_subnet" "cluster" {
  count        = var.create_network ? 1 : 0
  network_id   = hcloud_network.cluster[0].id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = var.private_network_cidr
}

# ── Static IPs for deterministic addressing ─────────────
locals {
  server_ips = var.create_network ? [for i in range(var.server_count) : cidrhost(var.private_network_cidr, 10 + i)] : []
  agent_ips  = var.create_network ? [for i in range(var.agent_count) : cidrhost(var.private_network_cidr, 100 + i)] : []
}

# ── Firewall ─────────────────────────────────────────────
resource "hcloud_firewall" "cluster" {
  name   = "${var.cluster_name}-fw"
  labels = merge({ cluster = var.cluster_name }, var.extra_labels)

  # SSH
  dynamic "rule" {
    for_each = length(var.ssh_allowed_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "22"
      source_ips = var.ssh_allowed_cidrs
    }
  }

  # k3s API
  dynamic "rule" {
    for_each = length(var.k3s_api_allowed_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "6443"
      source_ips = var.k3s_api_allowed_cidrs
    }
  }

  # WireGuard (intra-cluster via 10.0.0.0/8 when private network, else allow all)
  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820-51821"
    source_ips = var.create_network ? [var.private_network_cidr] : ["0.0.0.0/0", "::/0"]
  }

  # Inter-node rules (only when private network is enabled)
  dynamic "rule" {
    for_each = var.create_network ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "1-65535"
      source_ips = [var.private_network_cidr]
    }
  }

  dynamic "rule" {
    for_each = var.create_network ? [1] : []
    content {
      direction  = "in"
      protocol   = "udp"
      port       = "1-65535"
      source_ips = [var.private_network_cidr]
    }
  }

  dynamic "rule" {
    for_each = var.create_network ? [1] : []
    content {
      direction  = "in"
      protocol   = "icmp"
      source_ips = [var.private_network_cidr]
    }
  }

  # NodePort services
  dynamic "rule" {
    for_each = length(var.nodeport_allowed_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "30000-32767"
      source_ips = var.nodeport_allowed_cidrs
    }
  }

  # User-defined extra rules
  dynamic "rule" {
    for_each = var.extra_security_group_rules
    content {
      direction  = rule.value.type
      protocol   = rule.value.protocol
      port       = rule.value.start_port == rule.value.end_port ? tostring(rule.value.start_port) : "${rule.value.start_port}-${rule.value.end_port}"
      source_ips = rule.value.cidr != null ? [rule.value.cidr] : ["0.0.0.0/0", "::/0"]
    }
  }
}
