# ── Required ─────────────────────────────────────────────
variable "ssh_key_name" {
  description = "Name of an SSH key already registered in Exoscale"
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
  description = "Exoscale instance type for control-plane nodes (e.g. standard.medium, standard.large)"
  type        = string
  default     = "standard.medium"
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
  description = "Exoscale instance type for agent/worker nodes (e.g. standard.medium, standard.large)"
  type        = string
  default     = "standard.medium"
}

# ── Zone & template ─────────────────────────────────────
variable "zone" {
  description = "Exoscale zone (e.g. ch-gva-2, de-fra-1, de-muc-1, at-vie-1, at-vie-2, bg-sof-1)"
  type        = string
  default     = "ch-gva-2"
}

variable "template" {
  description = "OS template name for all nodes"
  type        = string
  default     = "Linux CentOS Stream 10 64-bit"
}

variable "disk_size" {
  description = "Disk size in GB for all nodes"
  type        = number
  default     = 50
}

# ── Networking ───────────────────────────────────────────
variable "create_network" {
  description = "Create a private network for inter-node communication. When false, nodes communicate over public IPs."
  type        = bool
  default     = false
}

variable "private_network_cidr" {
  description = "CIDR for the Exoscale private network"
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

# ── Security group (firewall) ─────────────────────────────
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
  description = "Additional security group rules to apply to all nodes"
  type = list(object({
    protocol               = string
    type                   = optional(string, "INGRESS")
    start_port             = number
    end_port               = number
    cidr                   = optional(string)
    user_security_group_id = optional(string)
    description            = optional(string)
  }))
  default = []
}
# ── Extra labels ─────────────────────────────────────────
variable "extra_labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
