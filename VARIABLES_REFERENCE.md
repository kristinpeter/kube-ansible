# Variables Reference Guide

[![Variables](https://img.shields.io/badge/Variables-Complete%20Reference-blue)](#variable-categories)
[![Configuration](https://img.shields.io/badge/Configuration-All%20Modes-green)](#deployment-modes)

📋 **Complete reference for all configuration variables** across bootstrap, full automation, and individual playbook modes.

## 📋 Table of Contents

1. [Variable Categories](#variable-categories)
2. [Deployment Mode Variables](#deployment-mode-variables)
3. [Global Variables](#global-variables)
4. [Cluster Automation Variables](#cluster-automation-variables)
5. [CNI Configuration Variables](#cni-configuration-variables)
6. [Group-Specific Variables](#group-specific-variables)
7. [Role Variables](#role-variables)
8. [Environment-Specific Variables](#environment-specific-variables)

---

## 🎯 Variable Categories

### 🔥 Critical Variables (Must Change)
Variables you **MUST** customize for your environment.

### ⚠️ Important Variables (Should Review)
Variables you **should review** and potentially customize.

### ✅ Default Variables (Usually OK)
Variables that work with default values in most environments.

---

## 🚀 Deployment Mode Variables

### Bootstrap Only Mode
Uses only **Global Variables** and **Group-Specific Variables**.

### Full Automation Mode  
Uses **all variables** including cluster automation and CNI configuration.

### Individual Playbook Mode
Uses specific variable subsets depending on which playbooks you run.

---

## 🌐 Global Variables (`group_vars/all.yml`)

### 🔥 Critical - Must Change

| Variable | Default Value | Purpose | Example |
|----------|---------------|---------|---------|
| `api_endpoint_name` | `"api.kube.homelab.lan"` | Kubernetes API endpoint FQDN | `"api.k8s.company.com"` |

### ⚠️ Important - Should Review

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `pod_subnet` | `"10.244.0.0/16"` | Pod network CIDR | If conflicts with existing networks |
| `service_subnet` | `"10.96.0.0/12"` | Service network CIDR | If conflicts with existing networks |
| `kubernetes_version` | `"v1.33"` | Kubernetes version to install | For specific version requirements |
| `configure_ntp` | `true` | Enable NTP time synchronization | **Keep true** - critical for clusters |
| `configure_firewall` | `false` | Enable UFW firewall rules | Set `true` if using UFW |

### ✅ Defaults Usually OK

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `containerd_version` | `"latest"` | containerd version |
| `pause_image_version` | `"3.10"` | Kubernetes pause container version |
| `disable_swap` | `true` | Disable swap for Kubernetes |
| `docker_apt_key_url` | Docker official URL | Docker repository GPG key |
| `kubernetes_apt_key_url` | Auto-generated | Kubernetes repository GPG key |

---

## 🤖 Cluster Automation Variables

### Deployment Mode Control

| Variable | Default Value | Purpose | Values |
|----------|---------------|---------|--------|
| `cluster_init_mode` | `"bootstrap_only"` | Deployment mode selection | `"bootstrap_only"`, `"full_automation"` |
| `cluster_init.enabled` | `false` | Enable cluster initialization | `true`, `false` |

### Cluster Initialization Settings

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `cluster_init.timeout` | `600` | Cluster init timeout (seconds) | For slow networks |
| `cluster_init.retry_count` | `3` | Number of retry attempts | For unreliable connections |
| `cluster_init.join_timeout` | `300` | Node join timeout (seconds) | For slow nodes |
| `cluster_init.upload_certs` | `true` | Upload certificates for HA masters | Keep `true` for HA |
| `cluster_init.kubeadm_init_extra_args` | `""` | Additional kubeadm init arguments | For custom configurations |

### Cluster Verification Settings

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `cluster_verification.enabled` | `true` | Enable cluster health verification | Usually keep enabled |
| `cluster_verification.required_nodes` | Auto-calculated | Expected number of nodes | Auto-calculated from inventory |
| `cluster_verification.timeout` | `300` | Verification timeout (seconds) | For slow clusters |
| `cluster_verification.check_interval` | `15` | Check interval (seconds) | For faster/slower polling |

### Health Check Configuration

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `cluster_verification.health_checks` | `["nodes_ready", "system_pods_ready", "cni_pods_ready", "api_server_healthy", "dns_resolution"]` | List of health checks to perform |

---

## 🌐 CNI Configuration Variables

### CNI Plugin Selection

| Variable | Default Value | Purpose | Options |
|----------|---------------|---------|---------|
| `cni_plugin.type` | `"calico"` | CNI plugin to install | `"calico"`, `"flannel"`, `"custom"`, `"none"` |
| `cni_plugin.enabled` | `true` | Enable CNI installation | `true`, `false` |

### Calico Configuration

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `cni_plugin.calico.version` | `"v3.29"` | Calico version | For specific versions |
| `cni_plugin.calico.operator_url` | Official Tigera URL | Calico operator manifest URL | For offline installs |
| `cni_plugin.calico.operator_crds_url` | Official Tigera URL | Calico CRDs manifest URL | For offline installs |
| `cni_plugin.calico.custom_resources_url` | Official Tigera URL | Calico custom resources URL | For offline installs |

### Calico Installation Configuration

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `cni_plugin.calico.installation_config.cidr` | `"{{ pod_subnet }}"` | Pod network CIDR for Calico | Usually matches `pod_subnet` |
| `cni_plugin.calico.installation_config.encapsulation` | `"VXLANCrossSubnet"` | Calico encapsulation mode | For different network topologies |
| `cni_plugin.calico.installation_config.block_size` | `26` | IP block size per node | For different node densities |

### Flannel Configuration

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `cni_plugin.flannel.url` | Official Flannel URL | Flannel manifest URL | For offline installs |
| `cni_plugin.flannel.backend_type` | `"vxlan"` | Flannel backend type | For different network types |

### Custom CNI Configuration

| Variable | Default Value | Purpose | When to Use |
|----------|---------------|---------|-------------|
| `cni_plugin.custom.manifests` | `[]` | List of custom CNI manifests | For non-standard CNI plugins |

---

## 👥 Group-Specific Variables

### Master Nodes (`group_vars/k8s_masters.yml`)

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `master_firewall_ports` | Standard K8s ports | UFW ports for masters | For custom services |
| `k8s_master_bind_address` | `"0.0.0.0"` | API server bind address | For security restrictions |
| `k8s_api_secure_port` | `6443` | API server port | For non-standard ports |

### Worker Nodes (`group_vars/k8s_workers.yml`)

| Variable | Default Value | Purpose | When to Change |
|----------|---------------|---------|----------------|
| `worker_firewall_ports` | Standard K8s ports | UFW ports for workers | For custom services |
| `k8s_worker_max_pods` | `110` | Maximum pods per worker | Based on node resources |

---

## 🛠️ Role Variables

### Common Role (`roles/common/defaults/main.yml`)

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `common_packages` | Essential packages list | Basic system packages |
| `kernel_modules` | `["overlay", "br_netfilter"]` | Required kernel modules |
| `sysctl_config` | K8s networking settings | Kernel networking parameters |

### containerd Role (`roles/containerd/defaults/main.yml`)

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `containerd_config_default` | Standard containerd config | Base containerd configuration |
| `containerd_systemd_cgroup` | `true` | Use systemd cgroup driver |

### Kubernetes Role (`roles/kubernetes/defaults/main.yml`)

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `kubelet_extra_args` | `""` | Additional kubelet arguments |
| `kubeadm_extra_args` | `""` | Additional kubeadm arguments |

### Network Role (`roles/network/defaults/main.yml`)

| Variable | Default Value | Purpose |
|----------|---------------|---------|
| `ntp_servers` | Ubuntu pool servers | NTP servers for time sync |
| `allow_ntp_clients` | `false` | Allow NTP client connections |

---

## 🌍 Environment-Specific Variables

### Production Environment (`inventory/production/hosts.yml`)

```yaml
# Host-specific variables in inventory
kube-master1.company.com:
  ansible_host: 192.168.1.10
  k8s_role: master
  k8s_master_primary: true

kube-worker1.company.com:
  ansible_host: 192.168.1.20
  k8s_role: worker
```

### Staging Environment (`inventory/staging/hosts.yml`)

Similar structure but with staging hostnames and IPs.

---

## 📝 Variable Usage Examples

### Minimal Production Configuration
```yaml
# group_vars/all.yml - Only change these for basic setup
api_endpoint_name: "api.k8s.company.com"
pod_subnet: "10.244.0.0/16"
service_subnet: "10.96.0.0/12"
```

### Full Automation Configuration
```yaml
# group_vars/all.yml - For zero-touch deployment
api_endpoint_name: "api.k8s.company.com"
cluster_init_mode: "full_automation"
cluster_init:
  enabled: true
  timeout: 600
  retry_count: 3

cni_plugin:
  type: "calico"
  enabled: true
```

### Custom Network Configuration
```yaml
# group_vars/all.yml - For custom networking
api_endpoint_name: "api.k8s.company.com"
pod_subnet: "172.16.0.0/16"           # Custom pod network
service_subnet: "172.17.0.0/16"       # Custom service network

cni_plugin:
  type: "calico"
  calico:
    installation_config:
      cidr: "172.16.0.0/16"           # Must match pod_subnet
      encapsulation: "IPIP"           # Different encapsulation
      block_size: 24                 # Smaller blocks
```

### Development Environment
```yaml
# group_vars/all.yml - For dev clusters
api_endpoint_name: "api.dev.k8s.company.com"
cluster_init_mode: "full_automation"
cluster_init:
  enabled: true
  timeout: 300                      # Faster timeout
  
cluster_verification:
  timeout: 180                      # Quick verification
  check_interval: 10                # Faster polling
```

---

## 🔧 Variable Override Methods

### 1. Command Line Override
```bash
# Override during playbook execution
ansible-playbook cluster-deploy.yml \
  --extra-vars "api_endpoint_name=api.custom.com cluster_init_mode=full_automation"
```

### 2. Environment File Override
```bash
# Create custom environment file
echo "api_endpoint_name: api.custom.com" > custom-vars.yml
ansible-playbook cluster-deploy.yml --extra-vars "@custom-vars.yml"
```

### 3. Host-Specific Override
```yaml
# In inventory file
kube-master1.company.com:
  ansible_host: 192.168.1.10
  k8s_worker_max_pods: 200  # Override default for this host
```

---

## ⚠️ Variable Validation

### Required Variables Check
The automation includes validation for critical variables:

```yaml
# These will cause failures if not properly set
- api_endpoint_name cannot be default value
- cluster_init_mode must be valid option
- CNI plugin type must be supported
```

### Common Variable Mistakes

| Mistake | Result | Solution |
|---------|--------|----------|
| Forgot to change `api_endpoint_name` | DNS resolution fails | Update to your actual endpoint |
| Network CIDR conflicts | Pod networking fails | Choose non-conflicting subnets |
| Wrong CNI type | CNI installation fails | Use supported CNI types |
| Disabled NTP | Time sync issues | Keep `configure_ntp: true` |

---

## 📚 Related Documentation

- **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Complete setup guide
- **[CLUSTER_AUTOMATION.md](CLUSTER_AUTOMATION.md)** - Automation details  
- **[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)** - Environment configuration
- **[group_vars/all.yml](group_vars/all.yml)** - Actual variable file

---

🎯 **Customize these variables to match your environment and requirements!**