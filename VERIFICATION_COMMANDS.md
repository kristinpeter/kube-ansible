# Kubernetes Cluster Verification Commands

[![Verification](https://img.shields.io/badge/Verification-Bootstrap%20%7C%20Cluster%20%7C%20CNI-green)](#verification-types)
[![Commands](https://img.shields.io/badge/Commands-Playbook%20%7C%20Manual-blue)](#verification-methods)

🔍 **Complete verification guide** for all deployment stages and methods.

## 📋 Table of Contents

1. [Verification Types](#verification-types)
2. [Verification Methods](#verification-methods)
3. [Bootstrap Verification](#bootstrap-verification)
4. [Cluster Verification](#cluster-verification)
5. [Full Automation Verification](#full-automation-verification)
6. [Individual Component Testing](#individual-component-testing)
7. [Troubleshooting Commands](#troubleshooting-commands)

---

## 🎯 Verification Types

### 🛡️ Bootstrap Verification
- **After:** Running `bootstrap.yml` or bootstrap-only mode
- **Purpose:** Confirm nodes are ready for cluster initialization
- **What's tested:** containerd, kubelet, Kubernetes packages

### 🚀 Cluster Verification  
- **After:** Manual cluster initialization or individual playbooks
- **Purpose:** Confirm cluster is healthy and operational
- **What's tested:** Nodes, pods, API server, DNS, CNI

### 🤖 Full Automation Verification
- **After:** Complete automation deployment
- **Purpose:** End-to-end cluster validation
- **What's tested:** Everything + kubeconfig download

---

## 🔧 Verification Methods

### Method 1: 📋 Automated Playbooks (Recommended)
```bash
# Bootstrap verification
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Complete cluster verification + kubeconfig download
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml
```

### Method 2: 🔍 Manual Commands (Detailed)
Individual Ansible and kubectl commands for step-by-step verification.

---

## 🛡️ Bootstrap Verification

### After Bootstrap Only Deployment
```bash
# 1. Test connectivity
ansible -i inventory/production/hosts.yml k8s_cluster -m ping

# 2. Verify containerd service
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl is-active containerd"

# 3. Verify kubelet service  
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl is-active kubelet"

# 4. Check Kubernetes version
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "kubeadm version -o short"

# 5. Verify swap is disabled
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "swapon --show"

# 6. Check kernel modules
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "lsmod | grep -E 'overlay|br_netfilter'"

# 7. Verify sysctl settings
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward"

# 8. Check API endpoint configuration
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "grep api.kube /etc/hosts"
```

### Bootstrap Success Indicators
```
✅ All nodes: ping SUCCESS
✅ containerd: active (running) on all nodes
✅ kubelet: active (running) on all nodes
✅ Kubernetes v1.33.4 installed
✅ swap: disabled (empty output)
✅ Kernel modules: overlay, br_netfilter loaded
✅ Sysctl: net.bridge.bridge-nf-call-iptables = 1, net.ipv4.ip_forward = 1
✅ API endpoint: configured in /etc/hosts
```

---

## 🚀 Cluster Verification

### After Cluster Initialization

#### Using Kubeconfig
```bash
# Set kubeconfig (if downloaded)
export KUBECONFIG=./kubeconfig/config

# OR SSH to master node
ssh ansible@kube-master1.YOUR-DOMAIN.com
```

#### Basic Cluster Health
```bash
# 1. Check cluster info
kubectl cluster-info

# 2. Verify all nodes are Ready
kubectl get nodes

# 3. Check all nodes detailed
kubectl get nodes -o wide

# 4. Verify system pods
kubectl get pods -n kube-system

# 5. Check CNI pods (Calico)
kubectl get pods -n calico-system

# 6. Verify API server health
kubectl get --raw /healthz

# 7. Check component status
kubectl get componentstatuses

# 8. Test DNS resolution
kubectl run test-dns --image=busybox:1.35 --rm -it --restart=Never \
  -- nslookup kubernetes.default.svc.cluster.local
```

#### Advanced Cluster Testing
```bash
# 9. Deploy test workload
kubectl create deployment nginx-test --image=nginx
kubectl expose deployment nginx-test --port=80 --type=NodePort

# 10. Verify test deployment
kubectl get deployment nginx-test
kubectl get pods -l app=nginx-test
kubectl get services nginx-test

# 11. Test pod networking
kubectl run test-pod --image=busybox:1.35 --rm -it --restart=Never \
  -- wget -qO- nginx-test.default.svc.cluster.local

# 12. Clean up test resources
kubectl delete deployment nginx-test
kubectl delete service nginx-test
```

### Cluster Success Indicators
```
✅ Cluster Info: API server accessible
✅ Nodes: All nodes in Ready state
✅ System Pods: All kube-system pods Running
✅ CNI Pods: All calico-system pods Running  
✅ API Health: /healthz returns "ok"
✅ DNS: Resolution working correctly
✅ Workloads: Test deployment successful
```

---

## 🤖 Full Automation Verification

### After Complete Automation Deployment
```bash
# 1. Verify kubeconfig downloaded
ls -la ./kubeconfig/config

# 2. Test local cluster access
export KUBECONFIG=./kubeconfig/config
kubectl get nodes

# 3. Comprehensive cluster check
kubectl get nodes,pods --all-namespaces

# 4. Verify all namespaces
kubectl get namespaces

# 5. Check all services
kubectl get services --all-namespaces

# 6. Test cluster functionality
kubectl create deployment test-automation --image=nginx
kubectl expose deployment test-automation --port=80 --type=NodePort
kubectl delete deployment,service test-automation
```

### Full Automation Success Indicators
```
🎉 Kubeconfig: ./kubeconfig/config exists and works
📊 Nodes: All 6 nodes Ready (3 masters + 3 workers)
✅ Namespaces: calico-system, kube-system, default present
🌐 CNI: Calico pods all Running
🚀 Functionality: Can deploy and access workloads
📥 Local Access: kubectl works from your machine
```

---

## 🧪 Individual Component Testing

### Test Specific Components

#### containerd Testing
```bash
# Check containerd config
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "containerd config dump | grep SystemdCgroup"

# List running containers
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "crictl ps"

# Check containerd status
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "crictl version"
```

#### kubelet Testing
```bash
# Check kubelet configuration
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl status kubelet --no-pager -l"

# View kubelet logs
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "journalctl -u kubelet --no-pager -l | tail -20"

# Check kubelet config
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "cat /var/lib/kubelet/kubeadm-flags.env"
```

#### Network Testing
```bash
# Check network interfaces
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "ip addr show"

# Verify routing
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "ip route"

# Test inter-node connectivity
ansible -i inventory/production/hosts.yml k8s_masters -m shell \
  -a "ping -c 3 kube-worker1.YOUR-DOMAIN.com"
```

#### CNI Testing (Calico)
```bash
# Check Calico status
kubectl get tigerastatus

# Verify Calico nodes
kubectl get pods -n calico-system -o wide

# Test pod-to-pod networking
kubectl run test1 --image=busybox:1.35 -- sleep 3600
kubectl run test2 --image=busybox:1.35 -- sleep 3600
kubectl exec test1 -- ping -c 3 $(kubectl get pod test2 -o jsonpath='{.status.podIP}')
kubectl delete pod test1 test2
```

---

## 🆘 Troubleshooting Commands

### Common Issue Diagnosis

#### SSH/Connectivity Issues
```bash
# Test SSH connectivity
ansible all -i inventory/production/hosts.yml -m ping -v

# Check SSH configuration
ansible all -i inventory/production/hosts.yml -m shell -a "whoami"

# Verify inventory parsing
ansible-inventory -i inventory/production/hosts.yml --list
```

#### Service Issues
```bash
# Check failed services
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl --failed"

# Restart services if needed
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl restart containerd kubelet"

# Check service dependencies
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl list-dependencies kubelet"
```

#### Cluster Issues
```bash
# Check existing cluster
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# View all events
kubectl get events --all-namespaces --sort-by=.metadata.creationTimestamp

# Check node conditions
kubectl describe nodes

# Check pod issues
kubectl get pods --all-namespaces | grep -v Running
```

#### Kubeconfig Issues
```bash
# Check kubeconfig location
ls -la ./kubeconfig/

# Verify kubeconfig content
cat ./kubeconfig/config | grep server:

# Test kubeconfig
kubectl --kubeconfig=./kubeconfig/config get nodes

# Re-download kubeconfig
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml
```

### Debug Information Collection
```bash
# Collect comprehensive debug info
mkdir -p debug-logs

# System information
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "uname -a && free -h && df -h" > debug-logs/system-info.txt

# Service status
ansible -i inventory/production/hosts.yml k8s_cluster -m shell \
  -a "systemctl status containerd kubelet" > debug-logs/services.txt

# Kubernetes information (if cluster exists)
kubectl get all --all-namespaces > debug-logs/k8s-resources.txt 2>/dev/null || true
kubectl describe nodes > debug-logs/nodes.txt 2>/dev/null || true
```

---

## 📚 Verification Playbooks Reference

| Playbook | Purpose | When to Use |
|----------|---------|-------------|
| `playbooks/verify-bootstrap.yml` | Verify bootstrap completion | After `bootstrap.yml` or bootstrap-only |
| `playbooks/detect-existing-cluster.yml` | Check for existing cluster | Before initialization |
| `playbooks/cluster/verify-cluster.yml` | Complete cluster verification + kubeconfig | After cluster deployment |

### Verification Playbook Examples
```bash
# Check what's already installed
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# Verify bootstrap only
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Full cluster health check + kubeconfig download
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml
```

---

🎯 **Use these commands to verify your deployment at any stage and troubleshoot issues effectively!**