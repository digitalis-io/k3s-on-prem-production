# K3s Ansible Playbook Modernization — Project Tracking

## Overview

Ansible playbook that provisions a hardened k3s Kubernetes cluster (3-master HA + 3 workers)
with CIS/STIG compliance, Falco runtime security, MetalLB load balancing, NGINX ingress,
Kubernetes dashboard, and Keepalived VIP.

---

## Task Status

### Phase 0: Tooling and Baseline

- [x] **Task 0.1** — Add `.ansible-lint`, `.yamllint.yml`, and `requirements.yml`
- [x] **Task 0.2** — Create GitHub Actions CI skeleton (lint + syntax-check jobs)

### Phase 1: Ansible Compatibility Fixes

- [x] **Task 1.1** — Remove `warn: no` from `roles/hardening/tasks/auditd.yml`
- [x] **Task 1.2** — Convert `yes`/`no` booleans to `true`/`false` across all YAML files
- [x] **Task 1.3** — Fix double-template `when` conditions
- [x] **Task 1.4** — Convert safe `include_tasks` to `import_tasks` where no runtime variables needed

### Phase 2: Secrets Management

- [x] **Task 2.1** — Migrate plaintext secrets to Ansible Vault
- [x] **Task 2.2** — Rotate all secrets (new values for cluster token, encryption key, Slack webhook)

### Phase 3: PSP Removal → Pod Security Admission

- [x] **Task 3.1** — Create PSA admission configuration and update k3s server templates
- [x] **Task 3.2** — Replace PSP deployment in `cluster_hardening.yml` with PSA namespace labels
- [x] **Task 3.3** — Remove PSP sections from ingress template
- [x] **Task 3.4** — Delete PSP policy files (no longer needed)

### Phase 4: K3s Version Upgrade

- [x] **Task 4.1** — Update k3s version variable to v1.32.2+k3s1
- [x] **Task 4.2** — Update k3s-selinux RPM to el9 package
- [x] **Task 4.3** — Parameterize k3s binary download for multi-arch (amd64/arm64)

### Phase 5: MetalLB Migration

- [x] **Task 5.1** — Update MetalLB version: `metallb_version: v0.14.9`
- [x] **Task 5.2** — Rewrite `roles/k3s-deploy/tasks/metallb.yml`
- [x] **Task 5.3** — Replace ConfigMap template with CRD templates

### Phase 6: NGINX Ingress Update

- [x] **Task 6.1** — Update ingress-nginx version: `nginx_ingress_version: 1.11.3`
- [x] **Task 6.2** — Switch to official release manifest approach

### Phase 7: Kubernetes Dashboard Update

- [x] **Task 7.1** — Update dashboard version to v2.7.6
- [x] **Task 7.2** — Fix service account token retrieval for Kubernetes 1.24+

### Phase 8: Kubeless Removal + Falco Pod-Delete

- [x] **Task 8.1** — Remove Kubeless entirely
- [x] **Task 8.2** — Configure Falcosidekick built-in pod-delete

### Phase 9: OS Target Update RHEL 8 → RHEL 9

- [x] **Task 9.1** — Update package lists for RHEL 9/Rocky 9
- [x] **Task 9.2** — Fix hardening role for RHEL 9

### Phase 10: Full CI/CD Integration Tests

- [x] **Task 10.1** — Add Molecule test scenarios for hardening and k3s-dependencies roles
- [x] **Task 10.2** — Add k3d integration test to GitHub Actions
- [x] **Task 10.3** — Add weekly version-drift detection workflow

### Phase 11: Ansible Best Practices Cleanup

- [x] **Task 11.1** — Add FQCN to all module references
- [x] **Task 11.2** — Add `changed_when: false` to all read-only command/shell tasks
- [x] **Task 11.3** — Add `meta/main.yml` to each role
- [x] **Task 11.4** — Replace magic numbers with variables
- [x] **Task 11.5** — Add `handlers/main.yml` to hardening role for sshd restart

---

## What NOT to Change

- The `firewalld` tasks using `command` over the module (intentional workaround for Ansible bug)
- The auditd restart via `/sbin/service auditd restart` (must use SysV path to flush rules)
- The `--protect-kernel-defaults=true` k3s flag (CIS requirement)
- The dual-network topology (eth0/eth1, internal/external MetalLB pools)
- The AES-CBC encryption at rest config (still supported in k3s v1.32)
