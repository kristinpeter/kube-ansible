# Safety Procedures for Production Environments

## 🛡️ **CRITICAL: Always Run Detection First**

**Before running any bootstrap automation**, always check for existing installations:

```bash
# STEP 1: Detect existing installations
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
```

---

## ⚠️ **What Happens in Dangerous Scenarios**

### **Scenario 1: Existing Kubernetes Cluster (Different Version)**

**If you have Kubernetes v1.32 and try to bootstrap v1.33.4:**

```bash
# What the automation would attempt:
❌ Hold packages at v1.33.4 (conflicts with v1.32)
❌ Restart kubelet with incompatible configuration  
❌ Potentially corrupt cluster state
❌ Break running workloads

# Symptoms:
- kubelet fails to start
- Nodes become NotReady
- Pods fail to schedule
- Cluster API becomes unstable
```

### **Scenario 2: cri-o Runtime Instead of containerd**

**If cri-o is running and we install containerd:**

```bash
# What the automation would attempt:
❌ Install containerd alongside cri-o
❌ Configure kubelet to use containerd socket
❌ Leave running pods connected to cri-o
❌ Create inconsistent runtime state

# Symptoms:
- New pods fail to start
- Existing pods become orphaned
- kubelet reports container runtime errors
- Mixed container states across runtimes
```

### **Scenario 3: Active Production Cluster**

**If cluster is serving production traffic:**

```bash
# What the automation would attempt:
❌ Restart critical services
❌ Change system configuration
❌ Potentially trigger node reboots
❌ Disrupt live workloads

# Symptoms:
- Service outages
- Pod evictions
- Data loss (if persistent volumes affected)
- SLA breaches
```

---

## 🔧 **Safe Resolution Procedures**

### **Option 1: Detect and Abort (Recommended)**

```bash
# 1. Always run detection first
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# 2. If existing installations found, STOP
# 3. Use one of the options below
```

### **Option 2: Clean Nodes First (Destructive but Safe)**

```bash
# WARNING: This removes existing Kubernetes completely
# Only use if you want to rebuild the cluster

# Stop services
ansible -i inventory/production/hosts.yml k8s_cluster -m shell -a "systemctl stop kubelet kubeproxy || true" --become

# Remove packages  
ansible -i inventory/production/hosts.yml k8s_cluster -m shell -a "apt-mark unhold kubelet kubeadm kubectl && apt remove -y kubelet kubeadm kubectl" --become

# Clean configuration
ansible -i inventory/production/hosts.yml k8s_cluster -m shell -a "rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd" --become

# Reset iptables
ansible -i inventory/production/hosts.yml k8s_cluster -m shell -a "iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X" --become

# NOW safe to run bootstrap
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml
```

### **Option 3: Force Mode (DANGEROUS - Expert Only)**

```bash
# ONLY use if you understand the risks
# This bypasses safety checks

ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --extra-vars "force_bootstrap=true"

# ⚠️ This could cause:
# - Service disruption
# - Data corruption  
# - Cluster instability
# - Unpredictable behavior
```

### **Option 4: Version Upgrade (Controlled)**

**For upgrading existing clusters, use proper upgrade procedures:**

```bash
# DON'T use bootstrap automation for upgrades
# Use Kubernetes upgrade procedures instead:

# 1. Drain nodes
kubectl drain node-name --ignore-daemonsets

# 2. Upgrade control plane
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.4

# 3. Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt update && sudo apt install -y kubelet=1.33.4-* kubectl=1.33.4-*
sudo apt-mark hold kubelet kubectl

# 4. Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 5. Uncordon node
kubectl uncordon node-name
```

---

## 🚨 **Emergency Recovery Procedures**

### **If Bootstrap Breaks Existing Cluster**

```bash
# 1. IMMEDIATELY stop the playbook (Ctrl+C)

# 2. Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# 3. Check kubelet status on affected nodes
ansible -i inventory/production/hosts.yml k8s_cluster -m shell -a "systemctl status kubelet" --become

# 4. If kubelet is failing, check logs
ansible -i inventory/production/hosts.yml k8s_cluster -m shell -a "journalctl -u kubelet --no-pager -l" --become

# 5. Restore from backup (if available)
# OR
# 6. Use emergency recovery procedures for your cluster
```

### **Container Runtime Recovery**

```bash
# If containerd conflicts with cri-o:

# 1. Stop conflicting services
sudo systemctl stop kubelet containerd

# 2. Restore original runtime configuration
sudo systemctl start crio

# 3. Update kubelet configuration to use cri-o
sudo sed -i 's|/run/containerd/containerd.sock|/var/run/crio/crio.sock|' /var/lib/kubelet/kubeadm-flags.env

# 4. Restart kubelet
sudo systemctl restart kubelet
```

---

## ✅ **Production Best Practices**

### **1. Always Use Detection First**

```bash
# Never skip this step in production
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
```

### **2. Test in Staging**

```bash
# Use separate staging nodes
ansible-playbook -i inventory/staging/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml
```

### **3. Have Rollback Plan**

- ✅ Backup cluster state before any operations
- ✅ Test recovery procedures
- ✅ Document rollback steps
- ✅ Have emergency contacts ready

### **4. Use Maintenance Windows**

- ✅ Schedule during low-traffic periods
- ✅ Notify stakeholders
- ✅ Have monitoring in place
- ✅ Plan for rollback time

### **5. Monitor During Operations**

```bash
# Watch cluster health during any changes
watch kubectl get nodes
watch kubectl get pods --all-namespaces
```

---

## 📞 **Emergency Contacts**

When using this automation in production:

1. **Have backup plan ready**
2. **Monitor cluster health continuously**  
3. **Know how to rollback quickly**
4. **Test all procedures in staging first**

**Remember: Bootstrap automation is for clean nodes only. For existing clusters, use proper upgrade procedures!**