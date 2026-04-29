# ── Required ─────────────────────────────────────────────
variable "ssh_key_name" {
  description = "Name of an SSH key pair already registered in AWS"
  type        = string
  default     = ""
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for access (first key is used for the key pair)"
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
  description = "AWS EC2 instance type for control-plane nodes (e.g. t3.medium, t3.large, m6i.large)"
  type        = string
  default     = "t3.medium"
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
  description = "AWS EC2 instance type for agent/worker nodes (e.g. t3.medium, t3.large, m6i.large)"
  type        = string
  default     = "t3.medium"
}

# ── Region & AMI ─────────────────────────────────────────
variable "region" {
  description = "AWS region (e.g. eu-west-1, us-east-1)"
  type        = string
  default     = "eu-west-1"
}

variable "ami_id" {
  description = "AMI ID for all nodes. If empty, the latest Amazon Linux 2023 AMI is used as fallback."
  type        = string
  default     = ""
}

variable "disk_size" {
  description = "Root EBS volume size in GB for all nodes"
  type        = number
  default     = 50
}

# ── Networking ───────────────────────────────────────────
variable "create_network" {
  description = "Create a VPC and subnet for inter-node communication. When false, uses the default VPC."
  type        = bool
  default     = false
}

variable "private_network_cidr" {
  description = "CIDR for the AWS VPC"
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
    protocol    = string
    type        = optional(string, "ingress")
    start_port  = number
    end_port    = number
    cidr        = optional(string)
    description = optional(string)
  }))
  default = []
}

# ── Extra labels ─────────────────────────────────────────
variable "extra_labels" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_architecture" {
  description = "Architecture for the default AMI (amd64 or arm64). Must match instance type architecture."
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.ami_architecture)
    error_message = "AMI architecture must be 'amd64' or 'arm64'."
  }
}