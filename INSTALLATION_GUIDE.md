# Complete Installation Guide

This comprehensive guide walks you through deploying a production-ready Kubernetes cluster using Ansible automation.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Configuration](#configuration)
4. [Deployment Options](#deployment-options)
5. [Post-Installation](#post-installation)
6. [Production Considerations](#production-considerations)

---

## Prerequisites

### Infrastructure Requirements

**Node Specifications (Minimum):**
- **OS**: Ubuntu 24.04 LTS (fresh installation)
- **CPU**: 2 cores (4 cores recommended for masters)
- **RAM**: 2GB (4GB+ recommended)
- **Disk**: 20GB (50GB+ recommended)
- **Network**: All nodes must communicate with each other

**Supported Architectures:**
- amd64 (Intel/AMD 64-bit)
- arm64 (ARM 64-bit)
- armhf (ARM 32-bit)

**Cluster Layouts:**
```
Production (6 nodes):
├── 3 Masters (HA): kube-master1, kube-master2, kube-master3
└── 3 Workers: kube-worker1, kube-worker2, kube-worker3

Staging (2 nodes):
├── 1 Master: staging-master1
└── 1 Worker: staging-worker1
```

### Control Machine Requirements

**Ansible Control Node:**
- Linux, macOS, or WSL2 on Windows
- Python 3.8+
- Ansible 2.12+
- SSH client

**Network Requirements:**
- SSH access to all target nodes
- DNS resolution or `/etc/hosts` entries for all nodes
- Internet access for package downloads

---

## Environment Setup

### 1. Install Ansible

**On Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install python3-pip
pip3 install ansible
```

**On macOS:**
```bash
brew install ansible
# or
pip3 install ansible
```

**On RHEL/CentOS/Fedora:**
```bash
sudo dnf install python3-pip
pip3 install ansible
```

### 2. Clone and Setup Project

```bash
# Clone the repository
git clone https://github.com/your-username/kube-ansible.git
cd kube-ansible

# Install required Ansible collections
ansible-galaxy collection install -r requirements.yml
```

### 3. Configure SSH Access

```bash
# Generate SSH key for cluster management
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible

# Copy SSH key to all nodes (update hostnames for your environment)
for node in kube-master1 kube-master2 kube-master3 kube-worker1 kube-worker2 kube-worker3; do
  ssh-copy-id -i ~/.ssh/ansible.pub ansible@${node}.homelab.lan
done

# Test SSH connectivity
ssh -i ~/.ssh/ansible ansible@kube-master1.homelab.lan
```

### 4. Verify Ansible Installation

```bash
# Check Ansible version
ansible --version

# Test connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping
```

---

## Configuration

### 1. Update Inventory

Edit `inventory/production/hosts.yml` to match your environment:

```yaml
---
all:
  children:
    k8s_cluster:
      children:
        k8s_masters:
          hosts:
            kube-master1.YOUR-DOMAIN.lan:    # ⚠️ UPDATE THIS
              ansible_host: kube-master1.YOUR-DOMAIN.lan
              k8s_role: master
              k8s_master_primary: true
            kube-master2.YOUR-DOMAIN.lan:    # ⚠️ UPDATE THIS
              ansible_host: kube-master2.YOUR-DOMAIN.lan
              k8s_role: master
            kube-master3.YOUR-DOMAIN.lan:    # ⚠️ UPDATE THIS
              ansible_host: kube-master3.YOUR-DOMAIN.lan
              k8s_role: master
        k8s_workers:
          hosts:
            kube-worker1.YOUR-DOMAIN.lan:    # ⚠️ UPDATE THIS
              ansible_host: kube-worker1.YOUR-DOMAIN.lan
              k8s_role: worker
            kube-worker2.YOUR-DOMAIN.lan:    # ⚠️ UPDATE THIS
              ansible_host: kube-worker2.YOUR-DOMAIN.lan
              k8s_role: worker
            kube-worker3.YOUR-DOMAIN.lan:    # ⚠️ UPDATE THIS
              ansible_host: kube-worker3.YOUR-DOMAIN.lan
              k8s_role: worker
```

### 2. Update Variables

Edit `group_vars/all.yml` for your network configuration:

```yaml
# Network Configuration - UPDATE THESE
api_endpoint_name: "api.kube.YOUR-DOMAIN.lan"    # ⚠️ REQUIRED
pod_subnet: "10.244.0.0/16"                      # Change if conflicts
service_subnet: "10.96.0.0/12"                  # Change if conflicts

# Kubernetes Configuration
kubernetes_version: "v1.33"                     # Current version
disable_swap: true                               # Required for K8s
configure_ntp: true                              # Highly recommended

# Node IP Configuration (auto-detected by default)
# master1_ip: "192.168.1.21"    # Uncomment to set manually
```

### 3. Verify Ansible Configuration

Edit `ansible.cfg` if needed:

```ini
[defaults]
inventory = inventory/production/hosts.yml
remote_user = ansible                    # ⚠️ Your SSH username
private_key_file = ~/.ssh/ansible        # ⚠️ Your SSH key path
host_key_checking = True
retry_files_enabled = False
stdout_callback = yaml
interpreter_python = auto_silent

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

### 4. Test Configuration

```bash
# Test inventory structure
ansible-inventory -i inventory/production/hosts.yml --graph

# Test connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping
```

---

## Deployment Options

### Option 1: Bootstrap Only (Recommended for Production)

**Best for: Production environments where you want maximum control**

```bash
# Step 1: Safety check for existing installations
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# Step 2: Bootstrap all nodes (prepare for Kubernetes)
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# Step 3: Verify bootstrap completion
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Step 4: Manual cluster initialization
ssh ansible@kube-master1.homelab.lan
sudo kubeadm init \
  --control-plane-endpoint="api.kube.YOUR-DOMAIN.lan:6443" \
  --upload-certs \
  --pod-network-cidr="10.244.0.0/16"

# Step 5: Follow kubeadm output to join other nodes manually
```

**After Bootstrap, all nodes will have:**
- ✅ Ubuntu 24.04 updated and configured
- ✅ containerd runtime installed and running
- ✅ Kubernetes v1.33 components installed
- ✅ Network and security configuration applied
- ✅ Ready for cluster initialization

### Option 2: Semi-Automated (Controlled Stages)

**Best for: Staging environments or when you want automation with stage control**

```bash
# Steps 1-3: Same as Bootstrap Only
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Step 4: Initialize primary master automatically
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml

# Step 5: Join additional masters (HA setup)
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

**After Semi-Automated deployment:**
- ✅ Complete 6-node HA Kubernetes cluster
- ✅ All nodes showing "Ready" status
- ✅ Calico CNI installed and operational
- ✅ kubeconfig downloaded for external access
- ✅ Ready for production workloads

### Option 3: Test with Staging First

**Best for: Production deployments (always recommended)**

```bash
# Test complete workflow in staging environment first
ansible-playbook -i inventory/staging/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/verify-bootstrap.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/init-primary-master.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/join-workers.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/install-cni.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/verify-cluster.yml

# After successful staging test, deploy to production
# Repeat all commands with inventory/production/hosts.yml
```

---

## Post-Installation

### Cluster Access

**From Control Machine:**
```bash
# Use downloaded kubeconfig
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
kubectl get pods --all-namespaces

# Or copy to default location
cp ./kubeconfig/config ~/.kube/config
kubectl get nodes
```

**From Cluster Nodes:**
```bash
# SSH to any master node
ssh ansible@kube-master1.homelab.lan
kubectl get nodes
```

### Verify Installation

```bash
# Check all nodes are Ready
kubectl get nodes

# Check system pods
kubectl get pods --all-namespaces

# Check CNI status
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator

# Test cluster functionality
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get services nginx
```

### Basic Cluster Configuration

```bash
# Label worker nodes (optional)
kubectl label node kube-worker1 node-role.kubernetes.io/worker=worker
kubectl label node kube-worker2 node-role.kubernetes.io/worker=worker
kubectl label node kube-worker3 node-role.kubernetes.io/worker=worker

# Check cluster info
kubectl cluster-info
kubectl get componentstatuses
```

---

## Production Considerations

### Security Best Practices

1. **SSH Key Management:**
   - Use dedicated SSH keys for cluster management
   - Regularly rotate SSH keys
   - Disable password authentication

2. **Network Security:**
   - Configure firewalls appropriately
   - Use private networks when possible
   - Enable TLS for all communications

3. **Access Control:**
   - Implement RBAC policies
   - Use service accounts for applications
   - Audit cluster access regularly

### High Availability

**For Production Clusters:**
- Deploy 3 master nodes (odd number for etcd quorum)
- Use load balancer for API endpoint
- Ensure masters are on different physical hosts
- Configure regular etcd backups

### Monitoring and Maintenance

**Essential Monitoring:**
```bash
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods --all-namespaces

# Cluster events
kubectl get events --sort-by=.metadata.creationTimestamp
```

**Regular Maintenance:**
- Monitor node resource usage
- Keep Kubernetes components updated
- Backup etcd data regularly
- Monitor cluster logs for issues

### Scaling

**Add Worker Nodes:**
1. Bootstrap new node: `ansible-playbook bootstrap.yml --limit="new-worker"`
2. Join to cluster: `ansible-playbook playbooks/cluster/join-workers.yml --limit="new-worker"`

**Add Master Nodes:**
1. Bootstrap new node: `ansible-playbook bootstrap.yml --limit="new-master"`
2. Join to cluster: `ansible-playbook playbooks/cluster/join-masters.yml --limit="new-master"`

### Backup and Recovery

**Backup etcd:**
```bash
# Create etcd snapshot
ETCDCTL_API=3 etcdctl snapshot save snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

**Backup certificates:**
```bash
# Backup PKI directory
sudo tar -czf pki-backup.tar.gz /etc/kubernetes/pki/
```

### Troubleshooting Common Issues

| Issue | Solution |
|-------|----------|
| Nodes stuck in NotReady | Check CNI installation and logs |
| SSH connection fails | Verify SSH keys and network connectivity |
| containerd service fails | Check disk space and restart service |
| Pods stuck in Pending | Check node resources and taints |
| DNS resolution fails | Check CoreDNS pods and configuration |

---

## Next Steps

After successful installation:

1. **Deploy Applications**: Start deploying your workloads
2. **Set up Ingress**: Configure ingress controller for external access
3. **Add Monitoring**: Deploy Prometheus/Grafana for cluster monitoring
4. **Configure Storage**: Set up persistent volume storage
5. **Implement Backup**: Configure automated etcd backups
6. **Security Hardening**: Implement additional security policies

## Additional Resources

- **[COMMAND_REFERENCE.md](COMMAND_REFERENCE.md)** - Complete command reference
- **[MANUAL_PROCEDURES.md](MANUAL_PROCEDURES.md)** - Manual setup procedures
- **[SAFETY_PROCEDURES.md](SAFETY_PROCEDURES.md)** - Production safety guide
- **[VERIFICATION_COMMANDS.md](VERIFICATION_COMMANDS.md)** - Testing and verification
- **[VARIABLES_REFERENCE.md](VARIABLES_REFERENCE.md)** - Configuration options

---

**🎉 Congratulations!** You now have a production-ready Kubernetes cluster!