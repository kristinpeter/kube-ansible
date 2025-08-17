# CLAUDE.md

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with this Kubernetes automation project.

## Project Overview and Mission

This repository contains **production-ready Ansible automation** for bootstrapping and configuring freshly installed Ubuntu servers to create secure, scalable Kubernetes clusters. The project follows Ansible best practices for idempotent infrastructure management with a focus on safety, reliability, and professional deployment standards.

### Key Principles
- **Safety First**: Comprehensive pre-flight checks prevent destructive operations
- **Idempotent Operations**: All playbooks can be safely re-run multiple times
- **Production Ready**: Follows industry best practices and security standards
- **Semi-Automated**: Controlled deployment stages for maximum operational control
- **Well Documented**: Comprehensive guides for users and developers

## Current Project Status

### GitHub Repository
- **URL**: https://github.com/kristinpeter/kube-ansible
- **Primary Developer**: @kristinpeter
- **AI Assistant**: Claude Code (Anthropic)
- **License**: MIT
- **Public Repository**: Ready for community use and contributions

### Technical Stack
- **Target OS**: Ubuntu 24.04 LTS (Noble)
- **Container Runtime**: containerd v1.7.27+
- **Kubernetes Version**: v1.33.4
- **CNI**: Calico via Tigera Operator
- **Automation**: Ansible (latest stable)
- **Architecture**: Multi-master HA support (3 masters + 3 workers)

## Repository Structure

```
kube-ansible/                              # Clean GitHub repository
├── 🔒 .gitignore                         # Protects user credentials  
├── 📋 SETUP.md                           # User setup instructions
├── 📖 README.md                          # Main documentation
├── 📝 *.md                               # Complete documentation set
├── ⚙️  ansible.cfg.example               # Example configuration
├── 🚀 bootstrap.yml                      # Main bootstrap playbook
├── 📦 requirements.yml                   # Ansible dependencies
├── 📁 inventory/
│   ├── production/hosts.yml.example      # Production inventory template
│   └── staging/hosts.yml.example         # Staging inventory template
├── 📁 group_vars/
│   ├── all.yml.example                   # Example global variables
│   ├── k8s_masters.yml                   # Master node variables
│   └── k8s_workers.yml                   # Worker node variables
├── 📁 playbooks/
│   ├── detect-existing-cluster.yml       # Safety: Check for existing K8s
│   ├── verify-bootstrap.yml              # Verify bootstrap completion
│   └── cluster/                          # Individual stage playbooks
│       ├── init-primary-master.yml       # Initialize first master
│       ├── join-masters.yml              # Join additional masters
│       ├── join-workers.yml              # Join worker nodes
│       ├── install-cni.yml               # Install Calico CNI
│       └── verify-cluster.yml            # Final verification + kubeconfig
├── 📁 roles/                             # Ansible roles
│   ├── common/                           # Base Ubuntu configuration
│   ├── containerd/                       # Container runtime
│   ├── kubernetes/                       # K8s components
│   └── network/                          # Network & firewall
├── 📁 docs/development/                  # Development documentation
│   └── CLAUDE.md                         # This file - AI guidance
└── 📄 LICENSE                            # MIT license
```

## Security and Credential Management

### Protected Files (.gitignore)
- `ansible.cfg` - User-specific SSH settings
- `group_vars/all.yml` - User-specific API endpoints
- `inventory/*/hosts.yml` - User-specific hostnames
- `kubeconfig/` - Generated cluster configurations
- All SSH keys, certificates, and runtime files

### Example Files for Users
- `ansible.cfg.example` - Template SSH configuration
- `group_vars/all.yml.example` - Template with generic values
- `inventory/*/hosts.yml.example` - Template inventories
- Users copy `.example` files and customize for their environment

## Deployment Workflows

### Option 1: Bootstrap Only (Maximum Safety)
**For production environments where you want full manual control:**
1. Safety check: `detect-existing-cluster.yml`
2. Bootstrap: `bootstrap.yml` 
3. Verification: `verify-bootstrap.yml`
4. Manual cluster initialization via SSH

### Option 2: Semi-Automated (Controlled Stages)  
**Step-by-step control with automation benefits:**
1. Safety + Bootstrap + Verification (same as Option 1)
2. Initialize primary master: `init-primary-master.yml`
3. Join additional masters: `join-masters.yml` 
4. Join workers: `join-workers.yml`
5. Install Calico CNI: `install-cni.yml`
6. Final verification: `verify-cluster.yml`

### Option 3: Staging Test First
**Always recommended before production deployment:**
- Test complete workflow in staging environment first
- Then deploy to production with confidence

## Idempotency and Safety Features

### All Playbooks Are Safe to Re-run
✅ **Fully Idempotent**: bootstrap.yml, detect-existing-cluster.yml, verify-bootstrap.yml, install-cni.yml, verify-cluster.yml  
🛡️ **Protected with Safety Checks**: init-primary-master.yml, join-masters.yml, join-workers.yml

### Key Safety Mechanisms
- **init-primary-master.yml**: Checks for existing cluster, fails safely if cluster already running
- **join-workers.yml**: Checks for existing kubelet.conf, skips already joined workers  
- **join-masters.yml**: Similar protection for master nodes
- **All roles**: Use standard Ansible modules for idempotent operations

## Ansible Best Practices

### Idempotence Requirements
- All tasks must be idempotent - running multiple times produces the same result
- Use modules like `package`, `service`, `file`, `template` instead of shell commands when possible
- When using `shell` or `command`, include `creates`, `removes`, or `changed_when` parameters
- Use `stat` module to check file existence before operations

### Role Design Standards
- Each role should have a single responsibility (common, containerd, kubernetes, network)
- Use role dependencies in `meta/main.yml` for proper ordering
- Structure roles with: tasks/, handlers/, templates/, files/, vars/, defaults/
- Keep role variables in `defaults/main.yml` for overridability

### Variable Management
- Use descriptive variable names with prefixes (e.g., `k8s_version`, `containerd_version`)
- Define default values in role `defaults/main.yml`
- Use inventory groups: `k8s_masters`, `k8s_workers`, `k8s_cluster:children`
- Keep sensitive data in Ansible Vault files (if used)

### Handler Conventions
- Use handlers for service restarts and reloads
- Name handlers descriptively (e.g., "restart containerd", "reload systemd")
- Group related handlers in role `handlers/main.yml`

### Template and File Management
- Use Jinja2 templates for configuration files that need variables
- Keep static files in `files/` directory
- Template file names should match destination names when possible

## Common Operational Commands

### Basic Operations
```bash
# Test connectivity to all nodes
ansible k8s_cluster -i inventory/production/hosts.yml -m ping

# Check inventory structure  
ansible-inventory -i inventory/production/hosts.yml --graph

# Run syntax check
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --syntax-check

# Run playbook in check mode (dry run)
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --check
```

### Bootstrap-Only Workflow
```bash
# 1. Safety check for existing installations
ansible-playbook -i inventory/production/hosts.yml playbooks/detect-existing-cluster.yml

# 2. Bootstrap all nodes (prepare for Kubernetes)
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml

# 3. Verify bootstrap completion
ansible-playbook -i inventory/production/hosts.yml playbooks/verify-bootstrap.yml

# 4. Manual cluster initialization (SSH to primary master)
ssh ansible@kube-master1.your-domain.lan
sudo kubeadm init --control-plane-endpoint="api.kube.your-domain.lan:6443" --upload-certs --pod-network-cidr="10.244.0.0/16"
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

# Final step: Use your cluster
export KUBECONFIG=./kubeconfig/config
kubectl get nodes
```

### Selective Execution
```bash
# Run only specific tags
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --tags="containerd,kubernetes"

# Deploy to specific node types
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --limit="k8s_masters"

# Skip certain components
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml --skip-tags="ntp"

# Verbose output for troubleshooting
ansible-playbook -i inventory/production/hosts.yml bootstrap.yml -vvv
```

## Kubernetes Cluster Architecture

### Node Groups and Roles
- **k8s_masters**: Control plane nodes (typically 1 or 3 for HA)
- **k8s_workers**: Worker nodes for running workloads  
- **k8s_cluster**: Parent group containing all Kubernetes nodes

### Network Configuration
- **API Endpoint**: Configurable (e.g., api.kube.your-domain.lan:6443)
- **Pod Network**: 10.244.0.0/16 (Calico default, configurable)
- **Service Network**: 10.96.0.0/12 (Kubernetes default, configurable)
- **CNI**: Calico via Tigera Operator (official, supported approach)

### Cluster Initialization Flow
1. **Common Role**: Base Ubuntu configuration, updates, essential packages, NTP, kernel modules
2. **containerd Role**: Container runtime installation and configuration  
3. **Kubernetes Role**: Install kubeadm, kubelet, kubectl with proper versions
4. **Network Role**: Network configuration, firewall setup, IP forwarding
5. **Primary Master Init**: kubeadm init with HA configuration
6. **Master Join**: Additional masters join with certificates  
7. **Worker Join**: Workers join cluster using tokens
8. **CNI Installation**: Calico networking via Tigera Operator
9. **Verification**: Comprehensive cluster health checks

## Development Guidelines

### Code Quality Standards
- Use descriptive task names that explain the purpose
- Include `tags` for selective execution
- Use `become: yes` only when necessary
- Add `when` conditions for conditional execution
- Use `block` for error handling with `rescue`
- Never use emojis in task names or output (causes Unicode display issues)

### Testing Approach
- Test playbooks in check mode before execution
- Use staging environment for validation
- Test both fresh installations and updates
- Verify idempotency by running playbooks multiple times

### Variable Validation
- Prefix variables with role name to avoid conflicts
- Use `ansible_facts` instead of deprecated fact variables  
- Validate required variables using `assert` module
- Document variables in role README files

### Error Handling
- Use `failed_when` and `changed_when` appropriately
- Implement proper error messages with troubleshooting hints
- Use `rescue` blocks for graceful error recovery
- Never leave systems in broken states

## Git Workflow and Collaboration

### Branch Strategy
- **master**: Main production branch (always deployable)
- **feature/**: New features (e.g., `feature/add-monitoring`)
- **fix/**: Bug fixes (e.g., `fix/bootstrap-retry-logic`)  
- **docs/**: Documentation updates (e.g., `docs/improve-setup-guide`)

### Commit Message Format
```bash
git commit -m "Descriptive summary of changes

- Bullet point details of what changed
- Why the change was needed
- Any breaking changes or special notes

Co-authored-by: Claude <noreply@anthropic.com>"
```

### Pull Request Workflow
```bash
# 1. Create feature branch
git checkout -b feature/your-feature-name

# 2. Make changes and commit
git add .
git commit -m "Your descriptive message"

# 3. Push and create PR
git push -u origin feature/your-feature-name
gh pr create --title "Your Feature" --body "Detailed description"

# 4. After review, merge
gh pr merge --squash
```

## Documentation Standards

### User Documentation
- **README.md**: Main entry point, overview, quick start
- **SETUP.md**: Detailed first-time setup instructions
- **QUICK_START.md**: Fast deployment guide
- **INSTALLATION_GUIDE.md**: Comprehensive installation walkthrough
- **MANUAL_PROCEDURES.md**: Complete manual procedures for understanding
- **SAFETY_PROCEDURES.md**: Production safety and best practices
- **TROUBLESHOOTING.md**: Common issues and solutions

### Technical Documentation  
- **COMMAND_REFERENCE.md**: All commands and usage examples
- **VARIABLES_REFERENCE.md**: Complete variable documentation
- **VERIFICATION_COMMANDS.md**: Post-deployment testing guides
- **CONTRIBUTING.md**: Development and contribution guidelines

### Development Documentation
- **docs/development/CLAUDE.md**: This file - comprehensive AI guidance
- Keep updated with architectural decisions and lessons learned
- Document any deviations from standard practices

## Future Development Areas

### Potential Enhancements
- **Monitoring Integration**: Prometheus, Grafana, AlertManager
- **Backup Solutions**: etcd backup automation, disaster recovery
- **Security Hardening**: CIS benchmarks, security scanning
- **CI/CD Integration**: GitLab/GitHub Actions for testing
- **Multi-Cloud Support**: AWS, Azure, GCP specific configurations
- **Upgrade Automation**: Kubernetes version upgrade procedures

### Technical Debt Management
- Regularly review and update dependencies
- Monitor Kubernetes version compatibility
- Keep Ansible best practices current
- Update documentation as features evolve

## Important Operational Notes

### Pre-Session Context
When starting a new Claude Code session:
1. Read this file first for complete project context
2. Review recent commits for latest changes  
3. Check open issues or feature requests
4. Understand current development focus

### Critical Safety Reminders
- Always test in staging before production
- Verify credential handling and .gitignore coverage
- Maintain idempotency in all new code
- Follow established naming and structure conventions
- Update documentation with any architectural changes

### AI-Assisted Development Notes
- This project demonstrates modern AI-assisted development practices
- Maintain high code quality and professional standards
- Document decisions and rationale for future reference
- Keep user experience and production safety as top priorities

---

**Last Updated**: August 2025  
**Project Status**: Production Ready  
**GitHub**: https://github.com/kristinpeter/kube-ansible