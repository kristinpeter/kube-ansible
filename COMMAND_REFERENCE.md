# Kubernetes Cluster Command Reference

This guide provides step-by-step commands for each stage of Kubernetes cluster deployment using both automated Ansible playbooks and manual approaches.

## 📋 Table of Contents

1. [Quick Reference](#quick-reference)
2. [Safety and Pre-flight Checks](#safety-and-pre-flight-checks)
3. [Bootstrap Commands](#bootstrap-commands)
4. [Cluster Initialization Commands](#cluster-initialization-commands)
5. [Node Joining Commands](#node-joining-commands)
6. [CNI Installation Commands](#cni-installation-commands)
7. [Verification Commands](#verification-commands)
8. [Maintenance Commands](#maintenance-commands)
9. [Troubleshooting Commands](#troubleshooting-commands)

---

## Quick Reference

### Bootstrap Only Workflow
```bash
# 1. Safety check for existing installations
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# 2. Bootstrap all nodes (prepare for Kubernetes)
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# 3. Verify bootstrap completion
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# 4. Manual cluster initialization (SSH to primary master)
ssh ansible@kube-master1.homelab.lan
sudo kubeadm init --control-plane-endpoint="api.kube.homelab.lan:6443" --upload-certs --pod-network-cidr="10.244.0.0/16"
```

### Semi-Automated Workflow
```bash
# Steps 1-3: Same as Bootstrap Only
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Steps 4-8: Individual stage playbooks
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-masters.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-workers.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/install-cni.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml
```

---

## Safety and Pre-flight Checks

### Connectivity Test
```bash
# Test SSH connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping

# Test connectivity with custom timeout
ansible k8s_cluster -i inventory/production/hosts.yml -m ping -T 30

# Test specific node group
ansible k8s_masters -i inventory/production/hosts.yml -m ping
ansible k8s_workers -i inventory/production/hosts.yml -m ping
```

### Existing Installation Detection
```bash
# Run comprehensive safety check
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# Check specific node for existing Kubernetes
ansible kube-master1.homelab.lan -i inventory/production/hosts.yml -m shell -a "kubeadm version -o short 2>/dev/null || echo 'NOT_FOUND'"

# Check for running container runtimes
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "systemctl is-active containerd docker crio 2>/dev/null || echo 'NONE_RUNNING'"
```

### Basic Connectivity Check
```bash
# Test connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping

# Check inventory structure
ansible-inventory -i inventory/production/hosts.yml --graph
```

---

## Bootstrap Commands

### Full Bootstrap Automation
```bash
# Bootstrap all nodes with default settings
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# Bootstrap with verbose output
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml -vvv

# Bootstrap specific node types only
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --limit="k8s_masters"
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --limit="k8s_workers"

# Bootstrap with specific tags
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --tags="common,containerd"
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --tags="kubernetes"

# Skip specific components
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --skip-tags="ntp"
```

### Selective Bootstrap Commands
```bash
# Run dry run first
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --check

# Run syntax check
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --syntax-check

# Bootstrap specific host
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --limit="kube-master1.homelab.lan"
```

### Bootstrap Verification
```bash
# Verify bootstrap completion
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Quick bootstrap status check
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "systemctl is-active containerd && kubeadm version -o short"

# Check all services status
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "systemctl status containerd kubelet"
```

---

## Cluster Initialization Commands

### Automated Cluster Initialization
```bash
# Initialize primary master
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml

# Initialize with verbose output
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml -vvv

# Force re-initialization (dangerous!)
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml --extra-vars "force_cluster_init=true"
```

### Manual Cluster Initialization
```bash
# SSH to primary master and initialize manually
ssh ansible@kube-master1.homelab.lan

# Initialize cluster with custom settings
sudo kubeadm init \
  --control-plane-endpoint="api.kube.homelab.lan:6443" \
  --pod-network-cidr="10.244.0.0/16" \
  --service-cidr="10.96.0.0/12" \
  --upload-certs

# Set up kubectl for ansible user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify cluster initialization
kubectl cluster-info
kubectl get nodes
```

---

## Node Joining Commands

### Automated Node Joining
```bash
# Join additional masters (HA setup)
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-masters.yml

# Join worker nodes
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-workers.yml

# Join specific node
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-workers.yml --limit="kube-worker3.homelab.lan"
```

### Manual Node Joining
```bash
# Get join commands from primary master
ssh ansible@kube-master1.homelab.lan
kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes

# Generate fresh master join command
sudo kubeadm token create --print-join-command --certificate-key \
$(sudo kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)

# Generate fresh worker join command
sudo kubeadm token create --print-join-command

# Join master node manually (run on additional masters)
sudo kubeadm join api.kube.homelab.lan:6443 \
  --token TOKEN \
  --discovery-token-ca-cert-hash sha256:HASH \
  --control-plane \
  --certificate-key CERT_KEY

# Join worker node manually (run on workers)
sudo kubeadm join api.kube.homelab.lan:6443 \
  --token TOKEN \
  --discovery-token-ca-cert-hash sha256:HASH
```

---

## CNI Installation Commands

### Automated CNI Installation
```bash
# Install Calico CNI using Tigera Operator
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/install-cni.yml

# Install with verbose output
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/install-cni.yml -vvv
```

### Manual CNI Installation
```bash
# SSH to primary master
ssh ansible@kube-master1.homelab.lan

# Install Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Install Calico
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# Verify CNI installation
kubectl get pods -n calico-system
kubectl get pods -n tigera-operator
```

---

## Verification Commands

### Automated Verification
```bash
# Complete cluster verification
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml

# Verify and download kubeconfig
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml --tags="kubeconfig"
```

### Manual Verification Commands
```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods --all-namespaces

# Check component status
kubectl get componentstatuses

# Check system pods
kubectl get pods -n kube-system
kubectl get pods -n calico-system

# Test DNS resolution
kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Check cluster networking
kubectl get endpoints
kubectl get services --all-namespaces
```

---

## Maintenance Commands

### Node Management
```bash
# Check all node status
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "systemctl status containerd kubelet"

# Restart services on all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m systemd -a "name=containerd state=restarted" --become
ansible k8s_cluster -i inventory/production/hosts.yml -m systemd -a "name=kubelet state=restarted" --become

# Update packages (careful in production!)
ansible k8s_cluster -i inventory/production/hosts.yml -m apt -a "upgrade=dist update_cache=yes" --become
```

### Cluster Maintenance
```bash
# Drain node for maintenance
kubectl drain kube-worker1 --ignore-daemonsets --delete-emptydir-data

# Uncordon node after maintenance
kubectl uncordon kube-worker1

# Get cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces
```

---

## Troubleshooting Commands

### Connectivity Troubleshooting
```bash
# Test SSH connectivity with debug
ssh -v ansible@kube-master1.homelab.lan

# Check Ansible connectivity
ansible kube-master1.homelab.lan -i inventory/production/hosts.yml -m setup -v

# Check network connectivity between nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "ping -c 3 kube-master1.homelab.lan"
```

### Service Troubleshooting
```bash
# Check containerd logs
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "journalctl -u containerd --no-pager -l"

# Check kubelet logs
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "journalctl -u kubelet --no-pager -l"

# Check API server logs (on masters)
ansible k8s_masters -i inventory/production/hosts.yml -m shell -a "crictl logs \$(crictl ps -q --name kube-apiserver)" --become
```

### Cluster Troubleshooting
```bash
# Check cluster component logs
kubectl logs -n kube-system -l component=kube-apiserver
kubectl logs -n kube-system -l component=kube-controller-manager
kubectl logs -n kube-system -l component=kube-scheduler

# Check CNI logs
kubectl logs -n calico-system -l k8s-app=calico-node
kubectl logs -n tigera-operator -l k8s-app=tigera-operator

# Describe problematic pods
kubectl describe pod POD_NAME -n NAMESPACE

# Get cluster diagnostic information
kubectl cluster-info dump > cluster-dump.yaml
```

### Reset Commands (Destructive!)
```bash
# Reset individual node (removes from cluster)
ansible kube-worker1.homelab.lan -i inventory/production/hosts.yml -m shell -a "kubeadm reset --force" --become

# Clean up after reset
ansible kube-worker1.homelab.lan -i inventory/production/hosts.yml -m shell -a "rm -rf /etc/kubernetes/ /var/lib/etcd/" --become

# Reset entire cluster (DANGEROUS!)
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "kubeadm reset --force" --become
```

---

## Common Command Patterns

### Inventory Management
```bash
# List all hosts in inventory
ansible-inventory -i inventory/production/hosts.yml --list

# Test specific groups
ansible k8s_masters -i inventory/production/hosts.yml --list-hosts
ansible k8s_workers -i inventory/production/hosts.yml --list-hosts

# Run commands on specific host groups
ansible k8s_masters -i inventory/production/hosts.yml -m shell -a "kubectl get nodes"
```

### Selective Execution
```bash
# Use tags for selective execution
ansible-playbook bootstrap.yml --tags="common"
ansible-playbook bootstrap.yml --tags="containerd,kubernetes"
ansible-playbook bootstrap.yml --skip-tags="ntp"

# Use limits for specific hosts
ansible-playbook bootstrap.yml --limit="kube-master1.homelab.lan"
ansible-playbook bootstrap.yml --limit="k8s_masters"

# Combine tags and limits
ansible-playbook bootstrap.yml --limit="k8s_workers" --tags="containerd"
```

### Output and Debugging
```bash
# Increase verbosity
ansible-playbook bootstrap.yml -v    # verbose
ansible-playbook bootstrap.yml -vv   # more verbose
ansible-playbook bootstrap.yml -vvv  # debug

# Check mode (dry run)
ansible-playbook bootstrap.yml --check

# Syntax check
ansible-playbook bootstrap.yml --syntax-check

# Step mode (confirm each task)
ansible-playbook bootstrap.yml --step
```

---

## Environment-Specific Commands

### Staging Environment
```bash
# All commands with staging inventory
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/cluster/init-primary-master.yml
# ... etc
```

### Production Environment
```bash
# All commands with production inventory (default)
ansible-playbook bootstrap.yml  # Uses default inventory from ansible.cfg
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml  # Explicit
```

---

**💡 Pro Tips:**
- Always run syntax checks before executing playbooks in production
- Use `--check` mode to see what changes would be made
- Start with staging environment to test procedures
- Use tags to run specific components during troubleshooting
- Keep verbose logs (`-vvv`) for debugging complex issues