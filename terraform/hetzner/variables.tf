# ── Required ─────────────────────────────────────────────
variable "ssh_key_name" {
  description = "Name of an SSH key already registered in Hetzner Cloud"
  type        = string
  default     = ""
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for access"
  type        = list(string)
  default     = []
}

# ── Cluster identity ─────────────────────────────────────
variable "cluster_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "digitalis-k3s"
}

# ── Server (control-plane) ─────────────────────────────────
variable "server_type" {
  description = "Hetzner Cloud server type for control-plane nodes (e.g. cx22, cx32, cx42)"
  type        = string
  default     = "cx22"
}

variable "server_count" {
  description = "How many control plane servers"
  type        = number
  default     = 1
}

# ── Agent (worker) pool ──────────────────────────────────
variable "agent_count" {
  description = "Number of k3s agent (worker) nodes"
  type        = number
  default     = 1
}

variable "agent_type" {
  description = "Hetzner Cloud server type for agent/worker nodes (e.g. cx22, cx32, cx42)"
  type        = string
  default     = "cx22"
}

# ── Location & image ────────────────────────────────────
variable "location" {
  description = "Hetzner Cloud location (e.g. hel1, fsn1, nbg1, ash)"
  type        = string
  default     = "hel1"
}

variable "image" {
  description = "OS image name for all nodes"
  type        = string
  default     = "rocky-9"
}

# ── Networking ───────────────────────────────────────────
variable "create_network" {
  description = "Create a private network for inter-node communication. When false, nodes communicate over public IPs."
  type        = bool
  default     = false
}

variable "private_network_cidr" {
  description = "CIDR for the Hetzner private network"
  type        = string
  default     = "10.13.0.0/16"
}

variable "kubevip_vip_address" {
  description = "Virtual IP address for kube-vip control-plane HA. Used when create_network is true."
  type        = string
  default     = ""
}

variable "kubevip_external_ip_range" {
  description = "IP range for kube-vip external LoadBalancer services (e.g. 192.168.1.200-192.168.1.240)"
  type        = string
  default     = ""
}

variable "kubevip_internal_ip_range" {
  description = "IP range for kube-vip internal LoadBalancer services. Used when create_network is true."
  type        = string
  default     = ""
}

# ── Firewall ─────────────────────────────────────────────
variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH into nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "k3s_api_allowed_cidrs" {
  description = "CIDRs allowed to reach the k3s API (port 6443)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "nodeport_allowed_cidrs" {
  description = "CIDRs allowed to reach NodePort services (30000-32767). Set to empty list to disable."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "extra_security_group_rules" {
  description = "Additional firewall rules to apply to all nodes"
  type = list(object({
    protocol    = string
    type        = optional(string, "in")
    start_port  = number
    end_port    = number
    cidr        = optional(string)
    description = optional(string)
  }))
  default = []
}

# ── Extra labels ─────────────────────────────────────────
variable "extra_labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
