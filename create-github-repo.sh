#!/bin/bash

# GitHub Repository Creation Script
# Usage: ./create-github-repo.sh [repo-name] [description]

REPO_NAME=${1:-"kube-ansible"}
DESCRIPTION=${2:-"Production-ready Kubernetes cluster automation with Ansible - Bootstrap and semi-automated deployment for Ubuntu 24.04 with containerd runtime"}

echo "🚀 Creating GitHub repository: $REPO_NAME"
echo "📝 Description: $DESCRIPTION"
echo ""

# Check if gh CLI is available
if command -v gh &> /dev/null; then
    echo "✅ Using GitHub CLI..."
    
    # Create repository with gh CLI
    gh repo create "$REPO_NAME" \
        --description "$DESCRIPTION" \
        --public \
        --clone=false \
        --add-readme=false
    
    # Add remote
    git remote add origin "https://github.com/$(gh api user --jq .login)/$REPO_NAME.git"
    
    # Push to GitHub
    git push -u origin main
    
    echo "✅ Repository created and pushed!"
    echo "🌐 URL: https://github.com/$(gh api user --jq .login)/$REPO_NAME"
    
else
    echo "❌ GitHub CLI (gh) not found."
    echo ""
    echo "Manual steps:"
    echo "1. Go to https://github.com/new"
    echo "2. Repository name: $REPO_NAME"
    echo "3. Description: $DESCRIPTION"
    echo "4. Make it Public"
    echo "5. Don't initialize with README (we have one)"
    echo "6. Create repository"
    echo ""
    echo "Then run these commands:"
    echo "git remote add origin https://github.com/YOUR_USERNAME/$REPO_NAME.git"
    echo "git push -u origin main"
fi