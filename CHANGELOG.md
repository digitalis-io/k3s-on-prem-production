# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- `.ansible-lint`, `.yamllint.yml`, and `ansible.cfg` for enforced linting standards across all roles
- `requirements.yml` to pin Ansible Galaxy collection versions
- GitHub Actions workflow `ci.yml` running lint and syntax-check jobs on every push and pull request
- GitHub Actions workflow `integration.yml` running a k3d-based integration test pipeline
- GitHub Actions workflow `version-check.yml` for weekly upstream version-drift detection against k3s, MetalLB, ingress-nginx, and dashboard
- `.devcontainer/` with `Dockerfile`, `devcontainer.json`, and `init-firewall.sh` providing a VS Code devcontainer with the full Ansible and Kubernetes toolchain pre-installed
- Molecule test scenarios under `molecule/hardening/` and `molecule/k3s-dependencies/` with converge and verify playbooks for both roles
- Terraform module under `terraform/exoscale/` for provisioning cluster infrastructure on Exoscale cloud (control plane nodes, agents, outputs, and inventory template)
- `group_vars/kube_cluster/vars.yml` and `group_vars/kube_cluster/vault.yml` to replace plaintext secrets with Ansible Vault-encrypted values
- `roles/k3s-deploy/templates/k3s-admission.yaml.j2` implementing Pod Security Admission configuration to replace the removed PodSecurityPolicy resources
- `roles/k3s-deploy/tasks/kubevip.yml` and associated templates (`kube-vip-ds.yaml.j2`, `kube-vip-rbac.yaml.j2`, `kube-vip-cloud-provider-cm.yaml.j2`) replacing Keepalived with kube-vip for control plane VIP and load balancer management
- `templates/portainer/portainer-helmchart.yaml.j2` deploying Portainer via a k3s HelmChart resource
- `meta/main.yml` to every role declaring role metadata and Galaxy dependencies
- `handlers/main.yml` to the hardening role for deferred sshd restart on configuration changes
- `tests/integration/inventory.yml` for the k3d integration test scenario
- Multi-arch k3s binary download support in `k3s_binary.yml` (amd64 and arm64)

### Changed

- Target OS updated from RHEL 8 / CentOS 8 to RHEL 9 / Rocky Linux 9 throughout all roles, package lists, and SELinux RPM references
- k3s version updated to `v1.32.2+k3s1`
- k3s-selinux RPM updated to the el9 package variant
- MetalLB version updated to `v0.14.9`; `metallb.yml` rewritten to use CRD-based `IPAddressPool` and `L2Advertisement` resources instead of the deprecated ConfigMap approach
- ingress-nginx version updated to `1.11.3`; deployment switched from custom manifests to the official upstream release manifest
- Kubernetes Dashboard version updated to `v2.7.6`; service account token retrieval updated for Kubernetes 1.24+ (explicit `Secret` of type `kubernetes.io/service-account-token` replacing the deprecated auto-generated token)
- `cluster_hardening.yml` updated to apply PSA namespace labels (`pod-security.kubernetes.io/enforce`) in place of PodSecurityPolicy binding
- Package lists in the `k3s-dependencies` role updated for Rocky/RHEL 9 package names and repositories
- Hardening role updated for RHEL 9: filesystem mount options, kernel parameter paths, and `minimize_access` task targets revised
- Falcosidekick configured to use the built-in pod-delete response engine, removing the dependency on Kubeless
- `falcosidekick-manifest.yaml.j2` updated to enable the built-in pod-delete action
- All `yes`/`no` YAML boolean values converted to `true`/`false` for Ansible 2.12+ compatibility
- All `include_tasks` calls that do not require runtime variable selection converted to `import_tasks` for static analysis and linting compliance
- All module references updated to use fully qualified collection names (FQCN) throughout every role
- All read-only `command` and `shell` tasks annotated with `changed_when: false` to prevent spurious change reporting
- Magic numbers (port numbers, retry counts, timeouts) replaced with named variables in `defaults/main.yml`
- Double-template `when` conditions (e.g., `when: "{{ condition }}"`) corrected to bare Jinja2 expressions
- `warn: no` removed from `command` tasks in `auditd.yml`; tasks restructured to avoid the deprecated option
- `inventory.yaml` updated to reflect the RHEL 9 target hosts and variable layout

### Removed

- PodSecurityPolicy manifests: `restricted-psp.yaml`, `system-psp.yaml`, and `cluster-admin-role.yaml` (PSP API removed in Kubernetes 1.25)
- `roles/k3s-deploy/tasks/ingress.yml` and custom ingress manifests `nginx-ingress-external-manifest.yaml.j2` and `nginx-ingress-internal-manifest.yaml.j2`, superseded by the upstream release manifest approach
- `metallb-config-manifest.yaml.j2` (ConfigMap-based MetalLB configuration), superseded by CRD templates
- `cluster_keepalived.yml` and `keepalived.conf.j2`; Keepalived replaced by kube-vip
- Kubeless tasks, RBAC manifests, and the Falco remediation function template; functionality replaced by Falcosidekick built-in pod-delete
- Plaintext secret values from inventory and variable files; all secrets now stored exclusively in Ansible Vault

### Fixed

- Service account token retrieval for the Kubernetes Dashboard failing on clusters running Kubernetes 1.24+ due to removal of automatic secret creation for service accounts
- Molecule and CI linting failures caused by deprecated `yes`/`no` booleans, bare `include_tasks`, missing FQCN, and double-templated `when` conditions
- Spurious `changed` results on read-only `command` and `shell` tasks that prevented idempotency verification in CI
