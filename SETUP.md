# Initial Setup Instructions

## 🚀 Quick Setup (5 minutes)

After cloning this repository, you need to create configuration files from the provided examples:

### 1. Copy and Customize Configuration Files

```bash
# Copy inventory files
cp inventory/production/hosts.yml.example inventory/production/hosts.yml
cp inventory/staging/hosts.yml.example inventory/staging/hosts.yml

# Copy variables file  
cp group_vars/all.yml.example group_vars/all.yml

# Copy Ansible configuration
cp ansible.cfg.example ansible.cfg
```

### 2. Update Your Environment Details

**Edit `inventory/production/hosts.yml`:**
```bash
vim inventory/production/hosts.yml
# Replace all instances of:
# kube-master1.your-domain.lan → your-actual-master1-hostname
# kube-worker1.your-domain.lan → your-actual-worker1-hostname
# etc.
```

**Edit `group_vars/all.yml`:**
```bash
vim group_vars/all.yml
# Update this line:
# api_endpoint_name: "api.kube.your-domain.lan" → "api.kube.YOUR-ACTUAL-DOMAIN.lan"
```

**Edit `ansible.cfg`:**
```bash
vim ansible.cfg
# Update these lines:
# remote_user = ansible → your-ssh-username
# private_key_file = ~/.ssh/id_rsa → path-to-your-ssh-key
```

### 3. Verify Configuration

```bash
# Test connectivity
ansible k8s_cluster -i inventory/production/hosts.yml -m ping

# Check inventory structure
ansible-inventory -i inventory/production/hosts.yml --graph
```

### 4. You're Ready!

Now follow the deployment guide in [README.md](README.md) or [QUICK_START.md](QUICK_START.md).

---

## 🔒 Security Note

The `.gitignore` file is configured to prevent your actual configuration files from being committed to version control. Only the `.example` files will be tracked by git.

**Never commit files containing:**
- Real hostnames or IP addresses
- SSH keys or credentials
- API endpoints or domain names

Your actual `ansible.cfg`, `hosts.yml`, and `all.yml` files are automatically ignored by git.