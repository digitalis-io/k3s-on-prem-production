# terraform-exoscale-k3s

A Terraform module to deploy [k3s](https://k3s.io/) Kubernetes clusters on [Exoscale](https://www.exoscale.com/), built by [Digitalis.io](https://digitalis.io).

## Features

- Single control-plane server with configurable worker (agent) node pool
- Module-managed security group with configurable CIDR allowlists for SSH, k3s API, and NodePort services
- Optional private networking with static IP assignment
- WireGuard-native Flannel backend by default
- Optional tool installation: Helm, k9s, Stern

## Quick Start

Set your Exoscale API credentials:

```bash
export EXOSCALE_API_KEY="your-api-key"
export EXOSCALE_API_SECRET="your-api-secret"
```

Then create a minimal configuration:

```hcl
provider "exoscale" {}

module "k3s" {
  source       = "github.com/digitalis-io/terraform-exoscale-k3s"
  ssh_key_name = "my-ssh-key"
}

output "server_ip" {
  value = module.k3s.server_public_ip
}

output "kubeconfig_cmd" {
  value = module.k3s.kubeconfig_command
}
```

This creates a 3-node cluster (1 server + 2 agents) using `standard.medium` instances in Geneva (ch-gva-2).

> **Note:** The `exoscale` provider reads credentials from the `EXOSCALE_API_KEY` and `EXOSCALE_API_SECRET` environment variables automatically. You can also pass them explicitly via variables — see the [examples/](examples/) directory.

## Accessing the Cluster

After `terraform apply`, fetch the kubeconfig:

```bash
# Use the output command directly
$(terraform output -raw kubeconfig_cmd) > ~/.kube/config

# Or manually
ssh ubuntu@<server_ip> sudo cat /etc/rancher/k3s/k3s.yaml | \
  sed "s/127.0.0.1/<server_ip>/g" > ~/.kube/config
```

## Restricting Access

By default, SSH and the k3s API are open to all IPs. Restrict them to your network:

```hcl
module "k3s" {
  source       = "github.com/digitalis-io/terraform-exoscale-k3s"
  ssh_key_name = "my-ssh-key"

  ssh_allowed_cidrs     = ["203.0.113.0/24"]
  k3s_api_allowed_cidrs = ["203.0.113.0/24"]

  # Disable NodePort access from the internet
  nodeport_allowed_cidrs = []
}
```

## Custom Security Group Rules

Add extra rules using the `extra_security_group_rules` variable:

```hcl
module "k3s" {
  source       = "github.com/digitalis-io/terraform-exoscale-k3s"
  ssh_key_name = "my-ssh-key"

  extra_security_group_rules = [
    {
      protocol   = "TCP"
      start_port = 443
      end_port   = 443
      cidr       = "0.0.0.0/0"
      description = "Allow HTTPS"
    }
  ]
}
```

## Private Network

By default the module does not create a private network. Enable it with:

```hcl
module "k3s" {
  source         = "github.com/digitalis-io/terraform-exoscale-k3s"
  ssh_key_name   = "my-ssh-key"
  create_network = true
}
```

When `create_network = false` (default):

- No `exoscale_private_network` or network interface resources are created
- Agents join the cluster via the server's public IP
- Inter-node security group rules for the cluster are skipped
- The `network_id`, `server_private_ip`, and `agent_private_ips` outputs return empty/null values

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| exoscale provider | >= 0.62.0 |
| random provider | >= 3.5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `ssh_key_name` | Name of an SSH key already registered in Exoscale | `string` | `""` | no |
| `cluster_name` | Name prefix for all resources | `string` | `"digitalis-k3s"` | no |
| `server_type` | Exoscale instance type for control-plane node | `string` | `"standard.medium"` | no |
| `agent_count` | Number of worker nodes | `number` | `2` | no |
| `agent_type` | Exoscale instance type for worker nodes | `string` | `"standard.medium"` | no |
| `zone` | Exoscale zone | `string` | `"ch-gva-2"` | no |
| `template` | OS template name for all nodes | `string` | `"Linux Ubuntu 24.04 LTS 64-bit"` | no |
| `disk_size` | Disk size in GB for all nodes | `number` | `50` | no |
| `create_network` | Create a private network for inter-node communication | `bool` | `false` | no |
| `private_network_cidr` | CIDR for the private network | `string` | `"10.13.1.0/24"` | no |
| `ssh_allowed_cidrs` | CIDRs allowed to SSH into nodes | `list(string)` | `["0.0.0.0/0"]` | no |
| `k3s_api_allowed_cidrs` | CIDRs allowed to reach the k3s API (6443) | `list(string)` | `["0.0.0.0/0"]` | no |
| `nodeport_allowed_cidrs` | CIDRs allowed to reach NodePort services (30000-32767) | `list(string)` | `["0.0.0.0/0"]` | no |
| `extra_security_group_rules` | Additional security group rules for all nodes | `list(object)` | `[]` | no |
| `k3s_version` | k3s version (e.g. `v1.31.4+k3s1`). Empty = stable channel | `string` | `""` | no |
| `k3s_server_extra_args` | Extra arguments for k3s server install | `string` | `""` | no |
| `k3s_agent_extra_args` | Extra arguments for k3s agent install | `string` | `""` | no |
| `flannel_backend` | Flannel backend | `string` | `"wireguard-native"` | no |
| `install_helm` | Install Helm 3 on server node | `bool` | `true` | no |
| `install_k9s` | Install k9s on all nodes | `bool` | `true` | no |
| `install_stern` | Install Stern on all nodes | `bool` | `true` | no |
| `extra_labels` | Additional labels for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `server_public_ip` | Public IPv4 address of the server node |
| `server_private_ip` | Private IP of the server node |
| `agent_public_ips` | Map of agent node names to public IPv4 addresses |
| `agent_private_ips` | Map of agent node names to private IPs |
| `k3s_token` | k3s cluster token (sensitive) |
| `network_id` | ID of the Exoscale private network |
| `security_group_id` | ID of the cluster security group |
| `kubeconfig_command` | Command to fetch kubeconfig from the server |

## Architecture

The module creates the following resources:

- **Security group** with rules for SSH, k3s API, WireGuard, and NodePort services
- **Private network** (optional) for inter-node communication
- **Server node** running k3s in server mode (control plane)
- **Agent nodes** running k3s in agent mode (workers only)

All nodes are provisioned via cloud-init with automatic k3s installation and cluster joining.

## License

See [LICENSE](LICENSE) for details.
