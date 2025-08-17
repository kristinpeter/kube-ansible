# Complete Manual Kubernetes Cluster Setup Guide

This guide provides step-by-step manual procedures for setting up a Kubernetes cluster without Ansible automation. Each section corresponds to what the Ansible playbooks automate, allowing you to understand and perform the setup manually.

## 📋 Table of Contents

1. [Prerequisites and Planning](#prerequisites-and-planning)
2. [Phase 1: System Preparation (Bootstrap)](#phase-1-system-preparation-bootstrap)
3. [Phase 2: Cluster Initialization](#phase-2-cluster-initialization)
4. [Phase 3: Node Joining](#phase-3-node-joining)
5. [Phase 4: CNI Installation](#phase-4-cni-installation)
6. [Phase 5: Cluster Verification](#phase-5-cluster-verification)
7. [Troubleshooting Guide](#troubleshooting-guide)

---

## Prerequisites and Planning

### Infrastructure Requirements

**Minimum Node Specifications:**
- **OS**: Ubuntu 24.04 LTS
- **CPU**: 2 cores minimum
- **RAM**: 2GB minimum (4GB recommended)
- **Disk**: 20GB minimum
- **Network**: All nodes must be able to communicate with each other

**Network Planning:**
- **API Endpoint**: Choose a FQDN for your cluster API (e.g., `api.kube.homelab.lan`)
- **Pod Subnet**: `10.244.0.0/16` (default, change if conflicts)
- **Service Subnet**: `10.96.0.0/12` (default, change if conflicts)

**SSH Access:**
```bash
# Create SSH key for cluster management
ssh-keygen -t rsa -b 4096 -f ~/.ssh/k8s-cluster

# Copy to all nodes
for node in kube-master1 kube-master2 kube-master3 kube-worker1 kube-worker2 kube-worker3; do
  ssh-copy-id -i ~/.ssh/k8s-cluster.pub user@${node}.homelab.lan
done
```

---

## Phase 1: System Preparation (Bootstrap)

This phase corresponds to what `bootstrap.yml` and `playbooks/verify-bootstrap.yml` do automatically.

### Step 1.1: Safety Check for Existing Installations

**On each node:**
```bash
# Check for existing Kubernetes
if command -v kubeadm >/dev/null 2>&1; then
  echo "⚠️ kubeadm found: $(kubeadm version -o short)"
  echo "🛑 STOP: Existing Kubernetes installation detected!"
  exit 1
else
  echo "✅ No existing kubeadm installation"
fi

# Check for existing container runtimes
if systemctl is-active --quiet containerd; then
  echo "⚠️ containerd is running"
elif systemctl is-active --quiet docker; then
  echo "⚠️ Docker is running"
elif systemctl is-active --quiet crio; then
  echo "⚠️ CRI-O is running"
else
  echo "✅ No container runtime conflicts"
fi

# Check cluster membership
if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "🛑 STOP: Node appears to be part of existing cluster!"
  exit 1
else
  echo "✅ Node is not part of existing cluster"
fi
```

### Step 1.2: System Updates and Prerequisites

**On each node:**
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y apt-transport-https ca-certificates curl gpg software-properties-common

# Verify sufficient disk space (minimum 10GB)
df -h / | awk 'NR==2 {print "Available space: " $4}'
```

### Step 1.3: Time Synchronization Setup

**Critical for Kubernetes certificate validation:**
```bash
# Install and configure NTP
sudo apt install -y chrony

# Configure chrony (edit /etc/chrony/chrony.conf)
sudo tee /etc/chrony/chrony.conf << EOF
# Ubuntu default NTP servers
pool 0.ubuntu.pool.ntp.org iburst maxsources 4
pool 1.ubuntu.pool.ntp.org iburst maxsources 1
pool 2.ubuntu.pool.ntp.org iburst maxsources 1
pool 3.ubuntu.pool.ntp.org iburst maxsources 2

# This directive specify the location of the file containing ID/key pairs for
# NTP authentication.
keyfile /etc/chrony/chrony.keys

# This directive specify the file into which chronyd will store the rate
# information.
driftfile /var/lib/chrony/chrony.drift

# Uncomment the following line to turn logging on.
#log tracking measurements statistics

# Log files location.
logdir /var/log/chrony

# Stop bad estimates upsetting machine clock.
maxupdateskew 100.0

# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can't be used along with the 'rtcfile' directive.
rtcsync

# Step the system clock instead of slewing it if the adjustment is larger than
# one second, but only in the first three clock updates.
makestep 1 3
EOF

# Restart and enable chrony
sudo systemctl restart chrony
sudo systemctl enable chrony

# Verify time synchronization
chrony sources -v
```

### Step 1.4: Kernel Module and System Configuration

**Configure required kernel modules:**
```bash
# Load kernel modules immediately
sudo modprobe overlay
sudo modprobe br_netfilter

# Make modules persistent across reboots
sudo tee /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

# Verify modules are loaded
lsmod | grep -E "(overlay|br_netfilter)"
```

**Configure sysctl parameters:**
```bash
# Set Kubernetes-required sysctl parameters
sudo tee /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1  
net.ipv4.ip_forward = 1
EOF

# Apply settings immediately
sudo sysctl --system

# Verify settings
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

### Step 1.5: Disable Swap

**Kubernetes requires swap to be disabled:**
```bash
# Disable swap immediately
sudo swapoff -a

# Remove swap entries from fstab to make persistent
sudo cp /etc/fstab /etc/fstab.backup
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Verify swap is disabled
free -h | grep -i swap
# Should show 0B for swap
```

### Step 1.6: Install containerd Container Runtime

**Add Docker repository (for containerd):**
```bash
# Download and add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package list
sudo apt update
```

**Install and configure containerd:**
```bash
# Install containerd
sudo apt install -y containerd.io

# Create containerd configuration directory
sudo mkdir -p /etc/containerd

# Generate default configuration
containerd config default | sudo tee /etc/containerd/config.toml

# Configure systemd cgroup driver (required for Kubernetes)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Configure pause image
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:3.8"|sandbox_image = "registry.k8s.io/pause:3.10"|' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Verify containerd is running
sudo systemctl status containerd
ctr version
```

### Step 1.7: Install Kubernetes Components

**Add Kubernetes repository:**
```bash
# Download and add Kubernetes GPG key
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list
sudo apt update
```

**Install Kubernetes packages:**
```bash
# Install kubelet, kubeadm, and kubectl
sudo apt install -y kubelet kubeadm kubectl

# Prevent automatic updates of Kubernetes packages
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service (will fail to start until cluster is initialized - this is normal)
sudo systemctl enable kubelet

# Verify installations
kubeadm version -o short
kubelet --version
kubectl version --client
```

### Step 1.8: Configure API Endpoint

**On each node, add the API endpoint to /etc/hosts:**
```bash
# Replace with your actual master1 IP and domain
MASTER1_IP="192.168.1.10"  # Change this to your master1 IP
API_ENDPOINT="api.kube.homelab.lan"  # Change this to your chosen API endpoint

# Add API endpoint to /etc/hosts
echo "${MASTER1_IP} ${API_ENDPOINT}" | sudo tee -a /etc/hosts

# Verify the entry
grep "${API_ENDPOINT}" /etc/hosts
```

### Step 1.9: Bootstrap Verification

**Verify all bootstrap steps completed successfully:**
```bash
# Create verification script
cat << 'EOF' > verify_bootstrap.sh
#!/bin/bash

echo "=== BOOTSTRAP VERIFICATION ==="

# Check containerd
if systemctl is-active --quiet containerd; then
  echo "✅ containerd is running"
else
  echo "❌ containerd is not running"
  exit 1
fi

# Check Kubernetes version
if kubeadm version -o short | grep -q "v1.33"; then
  echo "✅ Kubernetes v1.33 installed"
else
  echo "❌ Kubernetes v1.33 not found"
  exit 1
fi

# Check kubelet is enabled
if systemctl is-enabled --quiet kubelet; then
  echo "✅ kubelet service is enabled"
else
  echo "❌ kubelet service is not enabled"
  exit 1
fi

# Check API endpoint
if grep -q "api.kube" /etc/hosts; then
  echo "✅ API endpoint configured in /etc/hosts"
else
  echo "❌ API endpoint not found in /etc/hosts"
  exit 1
fi

# Check IP forwarding
if sysctl net.ipv4.ip_forward | grep -q "= 1"; then
  echo "✅ IP forwarding is enabled"
else
  echo "❌ IP forwarding is not enabled"
  exit 1
fi

# Check swap is disabled
if free | grep -q "Swap:.*0.*0.*0"; then
  echo "✅ Swap is disabled"
else
  echo "❌ Swap is not disabled"
  exit 1
fi

# Check required kernel modules
if lsmod | grep -q overlay && lsmod | grep -q br_netfilter; then
  echo "✅ Required kernel modules are loaded"
else
  echo "❌ Required kernel modules are not loaded"
  exit 1
fi

echo ""
echo "🎉 Bootstrap verification successful!"
echo "✅ Node $(hostname) is ready for Kubernetes cluster initialization"
EOF

chmod +x verify_bootstrap.sh
./verify_bootstrap.sh
```

---

## Phase 2: Cluster Initialization

This phase corresponds to what `playbooks/cluster/init-primary-master.yml` does automatically.

### Step 2.1: Initialize Primary Master

**On the primary master node only (kube-master1):**

```bash
# Safety check: Ensure no existing cluster
if [ -f /etc/kubernetes/admin.conf ]; then
  echo "⚠️ Found existing cluster configuration!"
  echo "To proceed anyway, remove it first:"
  echo "sudo rm -rf /etc/kubernetes/"
  exit 1
fi

# Initialize the cluster
sudo kubeadm init \
  --control-plane-endpoint="api.kube.homelab.lan:6443" \
  --pod-network-cidr="10.244.0.0/16" \
  --service-cidr="10.96.0.0/12" \
  --upload-certs

# The above command will output join commands. SAVE THESE COMMANDS!
# Example output:
# kubeadm join api.kube.homelab.lan:6443 --token abc123.xyz789 \
#   --discovery-token-ca-cert-hash sha256:abcd1234... \
#   --control-plane --certificate-key efgh5678...
```

### Step 2.2: Configure kubectl for Admin User

**On the primary master:**
```bash
# Set up kubectl for regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Set up kubectl for root user (optional)
sudo mkdir -p /root/.kube
sudo cp -i /etc/kubernetes/admin.conf /root/.kube/config

# Test kubectl access
kubectl get nodes
# Should show master node in NotReady state (normal until CNI is installed)

# Check cluster info
kubectl cluster-info
```

### Step 2.3: Generate Fresh Join Commands (if needed)

**If you need to get join commands later:**
```bash
# For additional master nodes
kubeadm token create --print-join-command --certificate-key $(kubeadm init phase upload-certs --upload-certs 2>/dev/null | tail -1)

# For worker nodes  
kubeadm token create --print-join-command

# Save these commands for the next phase
```

---

## Phase 3: Node Joining

This phase corresponds to what `playbooks/cluster/join-masters.yml` and `playbooks/cluster/join-workers.yml` do automatically.

### Step 3.1: Join Additional Master Nodes

**On each additional master node (kube-master2, kube-master3):**

```bash
# Safety check: Ensure node is not already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "⚠️ Node appears to already be part of a cluster!"
  echo "To proceed anyway, reset first:"
  echo "sudo kubeadm reset"
  exit 1
fi

# Join as master node (use the command from primary master initialization)
# Replace with your actual join command from Step 2.1
sudo kubeadm join api.kube.homelab.lan:6443 \
  --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:abcd1234... \
  --control-plane \
  --certificate-key efgh5678...

# Set up kubectl access
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Verify node joined successfully
kubectl get nodes
```

### Step 3.2: Join Worker Nodes

**On each worker node (kube-worker1, kube-worker2, kube-worker3):**

```bash
# Safety check: Ensure node is not already joined
if [ -f /etc/kubernetes/kubelet.conf ]; then
  echo "⚠️ Node appears to already be part of a cluster!"
  echo "To proceed anyway, reset first:"
  echo "sudo kubeadm reset"
  exit 1
fi

# Join as worker node (use the worker join command from primary master)
# Replace with your actual worker join command from Step 2.1 or 2.3
sudo kubeadm join api.kube.homelab.lan:6443 \
  --token abc123.xyz789 \
  --discovery-token-ca-cert-hash sha256:abcd1234...

# Verify kubelet is running
sudo systemctl status kubelet
```

### Step 3.3: Verify All Nodes Joined

**From any master node:**
```bash
# Check all nodes are present
kubectl get nodes
# Should show all 6 nodes (3 masters + 3 workers) in NotReady state

# Check node details
kubectl get nodes -o wide

# Check for any issues
kubectl get events --sort-by=.metadata.creationTimestamp
```

---

## Phase 4: CNI Installation

This phase corresponds to what `playbooks/cluster/install-cni.yml` does automatically.

### Step 4.1: Install Calico CNI using Tigera Operator

**From the primary master node:**

```bash
# Step 1: Install Tigera Operator CRDs
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml

# Step 2: Install Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Step 3: Wait for operator to be ready
kubectl wait --for=condition=available --timeout=300s deployment/tigera-operator -n tigera-operator

# Step 4: Download and customize Calico resources
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml

# Edit the custom-resources.yaml to match your pod subnet
sed -i 's|cidr: 192.168.0.0/16|cidr: 10.244.0.0/16|' custom-resources.yaml

# Step 5: Apply Calico installation
kubectl create -f custom-resources.yaml

# Clean up downloaded file
rm custom-resources.yaml
```

### Step 4.2: Monitor Calico Installation

**Monitor the installation progress:**
```bash
# Watch Calico installation status
watch kubectl get tigerastatus

# Wait for Calico to be available (this may take several minutes)
kubectl wait --for=condition=Available tigerastatus/calico --timeout=600s

# Check Calico system pods
kubectl get pods -n calico-system

# Verify all pods are running
kubectl get pods -n calico-system --no-headers | grep -v Running
# Should return no output when all pods are running
```

### Step 4.3: Verify Network Functionality

**Wait for nodes to become Ready:**
```bash
# Monitor nodes becoming Ready (may take 2-5 minutes after CNI installation)
watch kubectl get nodes

# All nodes should show Ready status:
# NAME                         STATUS   ROLES           AGE   VERSION
# kube-master1.homelab.lan     Ready    control-plane   10m   v1.33.4
# kube-master2.homelab.lan     Ready    control-plane   8m    v1.33.4
# kube-master3.homelab.lan     Ready    control-plane   6m    v1.33.4
# kube-worker1.homelab.lan     Ready    <none>          4m    v1.33.4
# kube-worker2.homelab.lan     Ready    <none>          4m    v1.33.4
# kube-worker3.homelab.lan     Ready    <none>          4m    v1.33.4
```

---

## Phase 5: Cluster Verification

This phase corresponds to what `playbooks/cluster/verify-cluster.yml` does automatically.

### Step 5.1: Comprehensive Cluster Health Check

**From any master node:**
```bash
# Create comprehensive verification script
cat << 'EOF' > verify_cluster.sh
#!/bin/bash

echo "=== KUBERNETES CLUSTER VERIFICATION ==="
echo ""

# Check cluster info
echo "📋 CLUSTER INFORMATION:"
kubectl cluster-info
echo ""

# Check all nodes
echo "🔗 NODE STATUS:"
kubectl get nodes -o wide
echo ""

# Count nodes by status
READY_NODES=$(kubectl get nodes --no-headers | grep " Ready " | wc -l)
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
echo "✅ Ready Nodes: ${READY_NODES}/${TOTAL_NODES}"

if [ "$READY_NODES" != "$TOTAL_NODES" ]; then
  echo "❌ Not all nodes are Ready!"
  kubectl get nodes | grep -v " Ready "
  exit 1
fi
echo ""

# Check system pods
echo "🏭 SYSTEM PODS STATUS:"
kubectl get pods -n kube-system
echo ""

# Check Calico pods
echo "🌐 CALICO CNI STATUS:"
kubectl get pods -n calico-system
echo ""

# Check Tigera status
echo "🐅 TIGERA OPERATOR STATUS:"
kubectl get tigerastatus
echo ""

# Test DNS resolution
echo "🔍 DNS RESOLUTION TEST:"
kubectl run dns-test --image=busybox:1.35 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local || echo "DNS test failed"
echo ""

# Check all namespaces
echo "📦 ALL NAMESPACES:"
kubectl get namespaces
echo ""

# Check all services
echo "🌐 ALL SERVICES:"
kubectl get services --all-namespaces
echo ""

echo "🎉 CLUSTER VERIFICATION COMPLETE!"
echo ""
echo "✅ Your Kubernetes cluster is ready for production workloads!"
EOF

chmod +x verify_cluster.sh
./verify_cluster.sh
```

### Step 5.2: Download kubeconfig for External Access

**Create local kubeconfig file:**
```bash
# Create local kubeconfig directory on your workstation
mkdir -p ./kubeconfig

# Copy kubeconfig from master
scp user@kube-master1.homelab.lan:/etc/kubernetes/admin.conf ./kubeconfig/config

# Update server URL for external access
sed -i 's|server: https://.*:6443|server: https://api.kube.homelab.lan:6443|' ./kubeconfig/config

# Set proper permissions
chmod 600 ./kubeconfig/config

# Test external access
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
```

### Step 5.3: Deploy Test Application

**Verify cluster functionality with a test deployment:**
```bash
# Deploy test nginx application
kubectl create deployment test-nginx --image=nginx

# Expose the deployment
kubectl expose deployment test-nginx --port=80 --type=NodePort

# Wait for deployment to be ready
kubectl wait --for=condition=available --timeout=120s deployment/test-nginx

# Check deployment status
kubectl get deployment test-nginx
kubectl get pods -l app=test-nginx

# Get service details
kubectl get service test-nginx

# Test the application (get NodePort)
NODE_PORT=$(kubectl get service test-nginx -o jsonpath='{.spec.ports[0].nodePort}')
echo "Test nginx available at: http://any-node-ip:${NODE_PORT}"

# Clean up test deployment
kubectl delete deployment,service test-nginx
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. Bootstrap Phase Issues

**containerd service fails to start:**
```bash
# Check containerd status
sudo systemctl status containerd

# Check containerd configuration
sudo containerd config dump

# Restart containerd
sudo systemctl restart containerd

# Check logs
sudo journalctl -u containerd -f
```

**Kubernetes packages fail to install:**
```bash
# Check repository configuration
apt policy kubeadm

# Re-add repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
```

#### 2. Cluster Initialization Issues

**kubeadm init fails with port in use:**
```bash
# Check what's using port 6443
sudo netstat -tulpn | grep :6443

# If needed, kill the process or reset kubeadm
sudo kubeadm reset
```

**kubeadm init fails with swap enabled:**
```bash
# Disable swap immediately
sudo swapoff -a

# Check swap is disabled
free -h | grep -i swap

# Remove from fstab
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

#### 3. Node Joining Issues

**Join command fails with token expired:**
```bash
# Generate new join commands from master
kubeadm token create --print-join-command

# For masters, also need certificate key
kubeadm init phase upload-certs --upload-certs
```

**Node shows NotReady status:**
```bash
# Check kubelet status
sudo systemctl status kubelet

# Check kubelet logs
sudo journalctl -u kubelet -f

# Check CNI installation
kubectl get pods -n calico-system
```

#### 4. CNI Installation Issues

**Calico pods stuck in pending:**
```bash
# Check node resources
kubectl describe nodes

# Check pod events
kubectl describe pods -n calico-system

# Check if nodes have required labels
kubectl get nodes --show-labels
```

**Tigera operator fails:**
```bash
# Check operator logs
kubectl logs -n tigera-operator deployment/tigera-operator

# Check CRDs are installed
kubectl get crd | grep tigera

# Restart operator if needed
kubectl rollout restart deployment/tigera-operator -n tigera-operator
```

### Emergency Recovery Procedures

#### Reset Single Node
```bash
# Drain node (from master)
kubectl drain node-name --ignore-daemonsets --force

# Delete node (from master)
kubectl delete node node-name

# Reset node (on the node itself)
sudo kubeadm reset
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/

# Rejoin node using appropriate join command
```

#### Reset Entire Cluster
```bash
# On each node:
sudo kubeadm reset
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd/
sudo systemctl restart containerd
sudo systemctl restart kubelet

# Start over from Phase 2
```

### Verification Commands Reference

**Quick health check commands:**
```bash
# Check all nodes
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check CNI pods
kubectl get pods -n calico-system

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check component status
kubectl get componentstatus

# Check API server health
kubectl get --raw /healthz

# Test DNS
kubectl run dns-test --image=busybox:1.35 --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local
```

---

## Summary

This manual procedure guide covers the complete process of setting up a production Kubernetes cluster from scratch. Each phase builds upon the previous one:

1. **Bootstrap** - Prepares all nodes with required software and configuration
2. **Initialization** - Creates the cluster on the primary master
3. **Joining** - Adds additional masters and workers to the cluster
4. **CNI** - Installs networking to enable pod-to-pod communication
5. **Verification** - Confirms everything is working correctly

The corresponding Ansible playbooks automate these exact same steps, providing a reliable and repeatable way to deploy clusters while maintaining full visibility into what's being configured.

For automated deployment using these procedures, refer to the main project documentation and use the provided Ansible playbooks.