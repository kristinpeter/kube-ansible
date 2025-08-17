# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

This repository contains Ansible automation for bootstrapping and configuring freshly installed Ubuntu servers to create a Kubernetes cluster. The project follows Ansible best practices for idempotent infrastructure management.

## Repository Structure

```
kube-ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml          # Ansible Galaxy dependencies
├── bootstrap.yml            # Bootstrap playbook entry point
├── inventory/
│   ├── production/
│   │   ├── hosts.yml        # Production inventory
│   │   └── group_vars/      # Production-specific variables
│   └── staging/
│       ├── hosts.yml        # Staging inventory
│       └── group_vars/      # Staging-specific variables
├── group_vars/
│   ├── all.yml              # Variables for all hosts
│   ├── k8s_masters.yml      # Master node variables
│   └── k8s_workers.yml      # Worker node variables
├── host_vars/               # Host-specific variables
├── roles/
│   ├── common/              # Base Ubuntu configuration
│   ├── containerd/          # containerd installation and config
│   ├── kubernetes/          # Kubernetes installation
│   └── network/             # Network and firewall configuration
├── playbooks/
│   ├── detect-existing-cluster.yml  # Safety: Check for existing K8s
│   ├── verify-bootstrap.yml         # Verify bootstrap completion
│   └── cluster/                     # Individual stage playbooks
│       ├── init-primary-master.yml  # Initialize first master
│       ├── join-masters.yml         # Join additional masters
│       ├── join-workers.yml         # Join worker nodes
│       ├── install-cni.yml          # Install Calico CNI
│       └── verify-cluster.yml       # Final verification + kubeconfig
└── files/                   # Static files and templates
```

## Ansible Best Practices

### Idempotence
- All tasks must be idempotent - running multiple times produces the same result
- Use modules like `package`, `service`, `file`, `template` instead of shell commands when possible
- When using `shell` or `command`, include `creates`, `removes`, or `changed_when` parameters
- Use `stat` module to check file existence before operations

### Role Design
- Each role should have a single responsibility (common, containerd, kubernetes, etc.)
- Use role dependencies in `meta/main.yml` for proper ordering
- Structure roles with: tasks/, handlers/, templates/, files/, vars/, defaults/
- Keep role variables in `defaults/main.yml` for overridability

### Variables and Inventory
- Use descriptive variable names with prefixes (e.g., `k8s_version`, `containerd_version`)
- Define default values in role `defaults/main.yml`
- Use inventory groups: `k8s_masters`, `k8s_workers`, `k8s_cluster:children`
- Keep sensitive data in Ansible Vault files

### Handlers
- Use handlers for service restarts and reloads
- Name handlers descriptively (e.g., "restart containerd", "reload systemd")
- Group related handlers in role `handlers/main.yml`

### Templates and Files
- Use Jinja2 templates for configuration files that need variables
- Keep static files in `files/` directory
- Template file names should match destination names when possible

## Common Commands

```bash
# Install Ansible Galaxy requirements
ansible-galaxy install -r requirements.yml

# Test connectivity to all hosts
ansible all -i inventory/staging/hosts.yml -m ping

# Run syntax check
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml --syntax-check

# Run playbook in check mode (dry run)
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml --check

# Deploy to staging environment
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml

# Deploy to production environment
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# Run only specific tags
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml --tags="containerd,kubernetes"

# Run specific playbook
ansible-playbook -i inventory/staging/hosts.yml playbooks/bootstrap.yml

# Limit execution to specific hosts
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml --limit="k8s_masters"

# Semi-automated deployment commands
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-masters.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-workers.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/install-cni.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml
```

## Kubernetes Cluster Architecture

### Node Groups
- **k8s_masters**: Control plane nodes (typically 1 or 3 for HA)
- **k8s_workers**: Worker nodes for running workloads
- **k8s_cluster**: Parent group containing all Kubernetes nodes

### Bootstrap Process
1. **Common Role**: Base Ubuntu configuration, updates, essential packages
2. **containerd Role**: Container runtime installation and configuration
3. **Kubernetes Role**: Install kubeadm, kubelet, kubectl
4. **Network Role**: Network configuration and firewall setup

### Semi-Automated Deployment Process
1. **Safety Check**: Detect existing Kubernetes installations
2. **Bootstrap**: Prepare all nodes for Kubernetes
3. **Verification**: Verify bootstrap completion
4. **Initialize Primary Master**: Setup first control plane node
5. **Join Masters**: Add additional control plane nodes (HA)
6. **Join Workers**: Add worker nodes to cluster
7. **Install CNI**: Deploy Calico networking via Tigera Operator
8. **Final Verification**: Complete cluster health checks and kubeconfig download

## Development Guidelines

### Task Writing
- Use descriptive task names that explain the purpose
- Include `tags` for selective execution
- Use `become: yes` only when necessary
- Add `when` conditions for conditional execution
- Use `block` for error handling with `rescue`

### Variable Management
- Prefix variables with role name to avoid conflicts
- Use `ansible_facts` instead of deprecated fact variables
- Validate required variables using `assert` module
- Document variables in role README files

### Testing
- Test playbooks in check mode before execution
- Use staging environment for validation
- Implement molecule testing for roles when possible
- Test both fresh installations and updates

### Prompting and User Input
- Use `vars_prompt` for sensitive or environment-specific data
- Provide default values and validation for prompts
- Use `pause` module for confirmation prompts during critical operations
- Document required variables and their expected values