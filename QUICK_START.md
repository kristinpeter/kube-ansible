# Quick Start Guide - Kubernetes Bootstrap Ansible

## Fast Track Deployment

### Prerequisites (5 minutes)

1. **Install Ansible** (if not already installed):
   ```bash
   pip install ansible
   ```

2. **SSH Key Setup**:
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible
   
   # Copy to all nodes (update hostnames for your environment)
   for node in kube-master1 kube-master2 kube-master3 kube-worker1 kube-worker2 kube-worker3; do
     ssh-copy-id -i ~/.ssh/ansible.pub ansible@${node}.homelab.lan
   done
   ```

3. **Install Ansible Collections**:
   ```bash
   ansible-galaxy collection install -r requirements.yml
   ```

4. **Test Connectivity**:
   ```bash
   ansible k8s_cluster -i inventory/production/hosts.yml -m ping
   ```

### Critical Configuration (2 minutes)

#### 1. Update Inventory (`inventory/production/hosts.yml`)
```yaml
# UPDATE THESE HOSTNAMES TO MATCH YOUR ENVIRONMENT
k8s_masters:
  hosts:
    kube-master1.homelab.lan:  # UPDATE THIS
      k8s_role: master
      k8s_master_primary: true
    kube-master2.homelab.lan:  # UPDATE THIS  
      k8s_role: master
    kube-master3.homelab.lan:  # UPDATE THIS
      k8s_role: master

k8s_workers:
  hosts:
    kube-worker1.homelab.lan:  # UPDATE THIS
      k8s_role: worker
    kube-worker2.homelab.lan:  # UPDATE THIS
      k8s_role: worker
    kube-worker3.homelab.lan:  # UPDATE THIS
      k8s_role: worker
```

#### 2. Update Variables (`group_vars/all.yml`)
```yaml
# REQUIRED: Update API endpoint for your domain
api_endpoint_name: "api.kube.YOUR-DOMAIN.lan"  # UPDATE THIS

# OPTIONAL: Update if network conflicts
pod_subnet: "10.244.0.0/16"     # Change if needed
service_subnet: "10.96.0.0/12"  # Change if needed
```

#### 3. Verify ansible.cfg
```ini
remote_user = ansible              # Your SSH username
private_key_file = ~/.ssh/ansible  # Your SSH key path
```

### Deployment Options

#### Option 1: Bootstrap Only (Maximum Safety)
**Recommended for production - gives you full control over cluster initialization**

```bash
# 1. Safety check for existing installations
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# 2. Bootstrap all nodes (prepare for Kubernetes)
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# 3. Verify bootstrap completion
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# 4. Manual cluster initialization
ssh ansible@kube-master1.homelab.lan
sudo kubeadm init --control-plane-endpoint="api.kube.YOUR-DOMAIN.lan:6443" --upload-certs --pod-network-cidr="10.244.0.0/16"
# Follow the join commands output for other nodes
```

#### Option 2: Semi-Automated (Controlled Stages)
**Step-by-step automation with full control at each stage**

```bash
# Steps 1-3: Same as Bootstrap Only
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# Step 4: Initialize primary master
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/init-primary-master.yml

# Step 5: Join additional masters (HA setup)
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-masters.yml

# Step 6: Join worker nodes
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/join-workers.yml

# Step 7: Install Calico CNI
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/install-cni.yml

# Step 8: Final verification and kubeconfig download
ansible-playbook -i inventory/production/hosts.yml playbooks/cluster/verify-cluster.yml

# Step 9: Use your cluster
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
```

#### Option 3: Test with Staging First
**Always recommended before production deployment**

```bash
# Test complete workflow in staging environment first
ansible-playbook -i inventory/staging/hosts.yml playbooks/detect-existing-cluster.yml
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml
ansible-playbook -i inventory/staging/hosts.yml playbooks/verify-bootstrap.yml
# ... continue with cluster playbooks

# Then deploy to production with confidence
# ... repeat commands with inventory/production/hosts.yml
```

### Verification (2 minutes)

```bash
# Check all services are active
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "systemctl is-active containerd && kubeadm version -o short"

# Verify network configuration  
ansible k8s_cluster -i inventory/production/hosts.yml -m shell -a "grep api.kube /etc/hosts"

# Check cluster status (after cluster initialization)
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
kubectl get pods --all-namespaces
```

### Success Indicators

**After Bootstrap:**
```
[OK] containerd: active (running) on all nodes
[OK] Kubernetes v1.33.4 installed on all nodes  
[OK] API endpoint configured in /etc/hosts
[OK] All nodes show: "Ready for cluster initialization phase!"
```

**After Semi-Automated Deployment:**
```
[OK] All nodes show "Ready" status
[OK] Calico CNI installed and running
[OK] kubeconfig downloaded to ./kubeconfig/config
[OK] Cluster ready for production workloads
```

## Quick Troubleshooting

| Issue | Quick Fix |
|-------|-----------|
| SSH fails | `ssh-copy-id -i ~/.ssh/ansible.pub ansible@hostname` |
| Ping fails | Check hostnames in inventory and DNS resolution |
| containerd fails | `ansible node -m systemd -a "name=containerd state=restarted" --become` |
| Repository errors | Re-run bootstrap playbook (GPG keys will be refreshed) |
| Node stays NotReady | Check CNI installation with `kubectl get pods -n calico-system` |

## Next Steps

- **Detailed Instructions**: See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)
- **Manual Procedures**: See [MANUAL_PROCEDURES.md](MANUAL_PROCEDURES.md) 
- **Advanced Configuration**: See [VARIABLES_REFERENCE.md](VARIABLES_REFERENCE.md)
- **Production Safety**: See [SAFETY_PROCEDURES.md](SAFETY_PROCEDURES.md)