# Contributing to Kubernetes Bootstrap Ansible

Thank you for your interest in contributing to this project! This guide will help you get started.

## 🤝 How to Contribute

### Ways to Contribute
- 🐛 **Bug Reports**: Found an issue? Open a GitHub issue
- 🚀 **Feature Requests**: Have an idea? We'd love to hear it
- 📖 **Documentation**: Improve guides, fix typos, add examples
- 🔧 **Code Improvements**: Optimize roles, add features, fix bugs
- 🧪 **Testing**: Test on different environments, add test cases
- 🎯 **Use Cases**: Share your deployment scenarios

### Before You Start
1. **Check existing issues** to avoid duplicates
2. **Read the documentation** thoroughly
3. **Test your changes** in a safe environment
4. **Follow the coding standards** outlined below

## 🛠️ Development Setup

### Prerequisites
```bash
# Install required tools
pip install ansible ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
```

### Local Development
```bash
# Clone your fork
git clone https://github.com/YOUR-USERNAME/kube-ansible.git
cd kube-ansible

# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# Test your changes
# Commit and push
```

### Testing Your Changes
```bash
# Validate syntax
ansible-playbook --syntax-check bootstrap.yml
ansible-playbook --syntax-check playbooks/bootstrap.yml

# Run linting
yamllint .
ansible-lint bootstrap.yml

# Test on staging environment
ansible-playbook -i inventory/staging/hosts.yml bootstrap.yml --check
```

## 📋 Coding Standards

### Ansible Best Practices
- **Idempotency**: Tasks should be safe to run multiple times
- **Clear Naming**: Use descriptive task and variable names
- **Error Handling**: Include proper error handling and retries
- **Tags**: Use appropriate tags for selective execution
- **Documentation**: Comment complex logic

### YAML Formatting
- **Indentation**: Use 2 spaces (no tabs)
- **Line Length**: Maximum 120 characters
- **Quotes**: Use double quotes for strings with variables
- **Lists**: Use consistent list formatting

### Variable Naming
- **Descriptive**: Use clear, descriptive names
- **Consistent**: Follow existing naming patterns
- **Scoped**: Prefix with role name when appropriate

Example:
```yaml
# Good
- name: Install containerd container runtime
  apt:
    name: containerd.io
    state: present
    update_cache: yes
  register: containerd_install_result
  retries: 3
  until: containerd_install_result is succeeded
  tags:
    - containerd
    - packages

# Bad
- shell: apt-get install containerd.io -y
```

## 🔄 Pull Request Process

### Before Submitting
1. **Ensure tests pass**: All linting and syntax checks
2. **Update documentation**: If you change functionality
3. **Test thoroughly**: On staging environment
4. **Commit properly**: Clear, descriptive commit messages

### Pull Request Guidelines
- **Clear title**: Summarize the change in one line
- **Detailed description**: Explain what, why, and how
- **Link issues**: Reference related issue numbers
- **Screenshots**: Include for UI/output changes
- **Testing**: Describe how you tested the changes

### PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Other (please describe)

## Testing
- [ ] Syntax validation passed
- [ ] Linting passed
- [ ] Tested on staging environment
- [ ] Documentation updated

## Related Issues
Fixes #issue-number
```

## 🧪 Testing Guidelines

### Test Environments
- **Always test on staging first**
- **Use separate hosts** for staging and production
- **Test rollback scenarios**
- **Verify all components** after deployment

### Test Scenarios
1. **Fresh Installation**: Clean Ubuntu 24.04 systems
2. **Re-run Safety**: Running playbook multiple times
3. **Partial Failure Recovery**: Handling interrupted runs
4. **Different Architectures**: AMD64, ARM64 if available
5. **Network Scenarios**: Different network configurations

### Verification Checklist
```bash
# Required tests before submitting PR
□ Ansible syntax validation passes
□ YAML linting passes  
□ Ansible linting passes
□ Staging deployment succeeds
□ Verification script passes
□ Documentation is updated
□ No secrets committed
□ .gitignore covers new files
```

## 📚 Documentation Standards

### Update Requirements
- **README.md**: For major changes
- **INSTALLATION_GUIDE.md**: For setup procedures
- **VARIABLES_REFERENCE.md**: For new variables
- **Code comments**: For complex logic

### Writing Style
- **Clear and concise**: Easy to understand
- **Step-by-step**: Logical progression
- **Examples**: Include practical examples
- **Troubleshooting**: Common issues and solutions

## 🐛 Bug Report Template

```markdown
## Bug Description
Clear description of the bug

## Environment
- OS: Ubuntu 24.04
- Ansible Version: X.X.X
- Python Version: X.X.X
- Architecture: amd64/arm64

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Error Output
```
Paste error output here
```

## Additional Context
Any other relevant information
```

## 🚀 Feature Request Template

```markdown
## Feature Description
Clear description of the proposed feature

## Use Case
Why is this feature needed?

## Proposed Solution
How should this be implemented?

## Alternative Solutions
Other approaches considered

## Additional Context
Any other relevant information
```

## 📞 Getting Help

### Community
- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion

### Response Times
- **Bug reports**: We aim to respond within 48 hours
- **Feature requests**: May take longer to evaluate
- **Pull requests**: We'll review within a week

## 📝 Code of Conduct

### Our Standards
- **Be respectful**: Treat everyone with respect
- **Be constructive**: Provide helpful feedback
- **Be patient**: We're all learning
- **Be inclusive**: Welcome newcomers

### Unacceptable Behavior
- Harassment or discrimination
- Trolling or inflammatory comments
- Sharing private information
- Other unprofessional conduct

## 🎉 Recognition

Contributors will be:
- **Listed in README.md**
- **Mentioned in release notes**
- **Thanked in commit messages**

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as this project.

---

**Thank you for contributing to making Kubernetes deployment easier for everyone!** 🚀