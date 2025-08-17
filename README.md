# Kubernetes Cluster Bootstrap with Ansible

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ansible](https://img.shields.io/badge/Ansible-2.12%2B-red)](https://docs.ansible.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-orange)](https://ubuntu.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.33-blue)](https://kubernetes.io/)

**Production-ready Ansible automation** for Kubernetes cluster deployment on Ubuntu 24.04 servers with containerd runtime.

## Documentation Index

| Document | Description | When to Use |
|----------|-------------|-------------|
| **[QUICK_START.md](QUICK_START.md)** | Fast deployment guide for immediate setup | First time users, quick deployment |
| **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** | Comprehensive setup instructions | Detailed understanding, production setup |
| **[MANUAL_PROCEDURES.md](MANUAL_PROCEDURES.md)** | Complete manual setup guide without automation | Understanding what automation does, custom setups |
| **[COMMAND_REFERENCE.md](COMMAND_REFERENCE.md)** | All Ansible commands and usage examples | Daily operations, troubleshooting |
| **[SAFETY_PROCEDURES.md](SAFETY_PROCEDURES.md)** | Production safety guide and best practices | Before any production deployment |
| **[VERIFICATION_COMMANDS.md](VERIFICATION_COMMANDS.md)** | Post-deployment testing and validation | After deployment, health checks |
| **[VARIABLES_REFERENCE.md](VARIABLES_REFERENCE.md)** | Complete variable configuration guide | Customization, advanced configuration |
| **[CONTRIBUTING.md](CONTRIBUTING.md)** | Development and contribution guidelines | Contributors, developers |

---

## Project Overview

This project provides **safe, controlled automation** for deploying production Kubernetes clusters. Choose between bootstrap-only preparation for maximum control or semi-automated deployment for convenience.

### What This Project Does

- **System Preparation**: Ubuntu updates, packages, kernel modules, time sync
- **Container Runtime**: containerd installation and configuration  
- **Kubernetes Components**: kubeadm, kubelet, kubectl installation
- **Safety Controls**: Existing installation detection and protection
- **Semi-Automation**: Individual stage playbooks for controlled deployment
- **Production Ready**: Follows industry best practices and security standards

### What This Project Does NOT Do

- **No Full Automation**: No single-command cluster deployment
- **No Configuration Management**: Focus on bootstrap, not ongoing management
- **No Application Deployment**: Only cluster infrastructure setup

## Architecture

### Supported Cluster Layouts
```
Production Cluster (6 nodes):
├── Masters (HA): kube-master1, kube-master2, kube-master3
├── Workers: kube-worker1, kube-worker2, kube-worker3  
└── API Endpoint: api.kube.homelab.lan → kube-master1

Staging Cluster (2 nodes):
├── Master: staging-master1
└── Worker: staging-worker1
```

### Project Structure
```
kube-ansible/
├── bootstrap.yml                    # Main bootstrap playbook
├── inventory/
│   ├── production/hosts.yml          # Production 6-node cluster
│   └── staging/hosts.yml            # Staging 2-node cluster  
├── playbooks/
│   ├── detect-existing-cluster.yml  # Safety: Check for existing K8s
│   ├── verify-bootstrap.yml         # Verify bootstrap completion
│   └── cluster/                     # Individual stage playbooks
│       ├── init-primary-master.yml  # Initialize first master
│       ├── join-masters.yml         # Join additional masters
│       ├── join-workers.yml         # Join worker nodes
│       ├── install-cni.yml          # Install Calico CNI
│       └── verify-cluster.yml       # Final verification + kubeconfig
├── group_vars/all.yml               # Global configuration
└── roles/                           # Automation roles
    ├── common/                      # System preparation
    ├── containerd/                  # Container runtime
    ├── kubernetes/                  # K8s components
    └── network/                     # Network & firewall
```

## Quick Start

### Prerequisites (5 minutes)
```bash
# 1. Install Ansible (if not already installed)
pip install ansible

# 2. Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# 3. Configure SSH access
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible
for node in kube-master1 kube-master2 kube-master3 kube-worker1 kube-worker2 kube-worker3; do
  ssh-copy-id -i ~/.ssh/ansible.pub ansible@${node}.homelab.lan
done

# 4. Test connectivity
ansible k8s_cluster -i inventory/production/hosts.yml -m ping
```

### First-Time Setup

**📋 IMPORTANT: Complete the initial setup first:**

```bash
# 1. Copy example files and customize for your environment
# See SETUP.md for detailed instructions
cp inventory/production/hosts.yml.example inventory/production/hosts.yml
cp group_vars/all.yml.example group_vars/all.yml
cp ansible.cfg.example ansible.cfg

# 2. Edit files with your hostnames, SSH settings, and domain
# See SETUP.md for what to change

# 3. Test connectivity
ansible k8s_cluster -i inventory/production/hosts.yml -m ping
```

👉 **See [SETUP.md](SETUP.md) for complete first-time setup instructions**

## Deployment Workflows

### Option 1: Bootstrap Only (Maximum Safety)

**For production environments where you want full manual control:**

```bash
# Step 1: Safety check for existing installations
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# Step 2: Bootstrap all nodes (prepare for Kubernetes)
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# Step 3: Verify bootstrap completion
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Step 4: Manual cluster initialization
ssh ansible@kube-master1.homelab.lan
sudo kubeadm init --control-plane-endpoint="api.kube.homelab.lan:6443" --upload-certs --pod-network-cidr="10.244.0.0/16"
# Follow the join commands output for other nodes
```

### Option 2: Semi-Automated (Controlled Stages)

**For step-by-step control with automation benefits:**

```bash
# Steps 1-3: Same as Bootstrap Only
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Step 4: Initialize primary master automatically
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml

# Step 5: Join additional masters (if HA setup)
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-masters.yml

# Step 6: Join worker nodes
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-workers.yml

# Step 7: Install Calico CNI using Tigera Operator
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/install-cni.yml

# Step 8: Final verification and kubeconfig download
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml

# Step 9: Use your cluster immediately
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
```

### Option 3: Staging Test First

**Always recommended for production deployments:**

```bash
# Test complete workflow in staging environment first
ansible-playbook -i inventory/staging/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/verify-bootstrap.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/init-primary-master.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/join-workers.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/install-cni.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/verify-cluster.yml

# Then deploy to production with confidence
# ... repeat commands with inventory/production/hosts.yml
```

## Key Features

### Safety and Reliability
- **Existing Installation Detection**: Prevents accidental overwrites
- **Multi-layer Safety Checks**: Pre-flight validation at every stage  
- **Idempotent Operations**: Safe to run multiple times
- **Retry Logic**: Handles temporary network issues
- **Comprehensive Verification**: Health checks at each stage

### Production Standards
- **Industry Best Practices**: Follows Kubernetes and Ansible standards
- **Security Hardening**: Proper SSH, GPG keys, time sync
- **Multi-Architecture Support**: amd64, arm64, armhf
- **Resource Validation**: Disk space, memory, connectivity checks
- **Environment Separation**: Staging and production isolation

### Automation Features  
- **Bootstrap Automation**: Complete node preparation
- **HA Cluster Support**: Multi-master deployment
- **CNI Integration**: Official Calico Tigera Operator
- **kubeconfig Download**: Automatic external access setup
- **Tag-based Execution**: Run specific components only

## Common Operations

### Testing and Validation
```bash
# Test connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping

# Check bootstrap status on all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "systemctl is-active containerd && kubeadm version -o short"

# Verify configuration
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "grep api.kube /etc/hosts"

# Run syntax check before deployment
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --syntax-check

# Dry run deployment
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --check
```

### Selective Deployment
```bash
# Deploy specific components only
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --tags="containerd,kubernetes"

# Deploy to specific node types
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --limit="k8s_masters"

# Skip certain components
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --skip-tags="ntp"

# Verbose output for troubleshooting
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml -vvv
```

## Configuration Reference

### Required Variables (group_vars/all.yml)
```yaml
# Network Configuration
api_endpoint_name: "api.kube.homelab.lan"  # UPDATE THIS
pod_subnet: "10.244.0.0/16"                # Change if conflicts
service_subnet: "10.96.0.0/12"             # Change if conflicts

# Kubernetes Version
kubernetes_version: "v1.33"                # Latest stable

# System Configuration  
disable_swap: true                          # Required for K8s
configure_ntp: true                         # Highly recommended
```

### Inventory Configuration
```yaml
# inventory/production/hosts.yml
k8s_masters:
  hosts:
    kube-master1.YOUR-DOMAIN.lan:          # UPDATE THESE
      k8s_role: master
      k8s_master_primary: true
    # ... additional masters

k8s_workers: 
  hosts:
    kube-worker1.YOUR-DOMAIN.lan:          # UPDATE THESE
      k8s_role: worker
    # ... additional workers
```

## Troubleshooting

### Quick Diagnostics
```bash
# Test connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping

# Check if bootstrap completed successfully
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "which kubeadm && systemctl is-enabled containerd"

# Check cluster status (after cluster is formed)
kubectl --kubeconfig=./kubeconfig/config get nodes

# Reset problematic node (if needed)
ansible kube-worker1.homelab.lan -i inventory/production/hosts.yml -m shell -a "kubeadm reset --force" --become
```

### Common Issues
| Issue | Quick Fix | Documentation |
|-------|-----------|---------------|
| SSH connection fails | Check `ssh-copy-id` and ansible.cfg | [COMMAND_REFERENCE.md](COMMAND_REFERENCE.md#connectivity-test) |
| containerd fails | Check time sync and restart service | [MANUAL_PROCEDURES.md](MANUAL_PROCEDURES.md#troubleshooting-guide) |
| Node stays NotReady | Check CNI installation and logs | [VERIFICATION_COMMANDS.md](VERIFICATION_COMMANDS.md) |
| Package installation fails | Check repository configuration | [MANUAL_PROCEDURES.md](MANUAL_PROCEDURES.md#troubleshooting-guide) |

## Security Considerations

- **SSH Keys**: Use dedicated SSH keys for cluster management
- **Time Synchronization**: Critical for certificate validation  
- **Package Validation**: GPG signature verification for all packages
- **Network Security**: Firewall configuration support included
- **Existing Installation Detection**: Prevents accidental data loss

## What Happens After Deployment

### After Bootstrap Completion
```bash
# All nodes will show:
[OK] containerd: active (running)
[OK] Kubernetes v1.33 installed  
[OK] kubelet: enabled
[OK] Swap: disabled
[OK] Kernel modules: loaded
[OK] API endpoint: configured
[OK] Ready for cluster initialization
```

### After Semi-Automated Deployment  
```bash
# Complete operational cluster:
[OK] Multi-master HA cluster (if configured)
[OK] All nodes joined and Ready
[OK] Calico CNI installed via Tigera Operator
[OK] kubeconfig downloaded to ./kubeconfig/config
[OK] Ready for immediate production use

# Start using your cluster:
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
kubectl create deployment nginx --image=nginx
kubectl get pods
```

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Bug reporting guidelines
- Feature request process  
- Development setup
- Pull request procedures

### Quick Contribution
1. Fork the repository
2. Create feature branch: `git checkout -b feature/your-feature`
3. Test thoroughly in staging environment
4. Submit pull request with detailed description

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If this project helped you:
- **Star the repository**
- **Report issues** you encounter  
- **Contribute improvements**
- **Share with others**

---

## Success Stories

After successful deployment, you'll have:

- **Production-grade Kubernetes cluster** with optional HA masters
- **Calico networking** with advanced features  
- **Secure configuration** following industry best practices
- **External access** via downloaded kubeconfig
- **Monitoring ready** infrastructure for your workloads

**Ready to deploy production workloads immediately!**

---

## Contributors

- **Primary Developer**: [@kristinpeter](https://github.com/kristinpeter)
- **AI Assistant**: Claude Code (Anthropic) - Project architecture, automation design, and documentation

---

*For detailed step-by-step instructions, see [MANUAL_PROCEDURES.md](MANUAL_PROCEDURES.md)*  
*For command reference, see [COMMAND_REFERENCE.md](COMMAND_REFERENCE.md)*  
*For quick deployment, see [QUICK_START.md](QUICK_START.md)*