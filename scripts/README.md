# Scripts Directory

This directory contains helpful scripts for managing your ArgoCD per-app selective sync setup.

## 🚀 Quick Start

Use the main helper script for easy access to all functionality:

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Show all available commands
./scripts/argocd-helper.sh help

# Install ArgoCD and deploy applications
./scripts/argocd-helper.sh install-argocd
./scripts/argocd-helper.sh deploy

# Monitor your environments
./scripts/argocd-helper.sh monitor
```

## 📜 Available Scripts

### 🎯 Main Helper Script

| Script | Description |
|--------|-------------|
| **`argocd-helper.sh`** | **Main entry point** - provides easy access to all other scripts |

**Usage Examples:**
```bash
./scripts/argocd-helper.sh install-argocd
./scripts/argocd-helper.sh deploy
./scripts/argocd-helper.sh add-env qa --replicas 3
./scripts/argocd-helper.sh monitor --watch
./scripts/argocd-helper.sh status
```

### ⚙️ Setup & Installation

| Script | Description |
|--------|-------------|
| `install-argocd.sh` | Install ArgoCD on your Kubernetes cluster |
| `deploy-applications.sh` | Deploy the ApplicationSet and monitor application creation |

**Usage Examples:**
```bash
# Install ArgoCD
./scripts/install-argocd.sh

# Deploy all applications
./scripts/deploy-applications.sh
```

### 🏗️ Environment Management  

| Script | Description |
|--------|-------------|
| `add-environment.sh` | Add new environments with per-app structure |
| `cleanup-environments.sh` | Remove per-app applications and clean up resources |
| `test-per-app-hooks.sh` | Demo script showing per-app hook behavior |
| `reset-argocd.sh` | Reset ArgoCD to clean state (removes all applications) |

**Usage Examples:**
```bash
# Add a new QA environment
./scripts/add-environment.sh qa --replicas 3 --service-type NodePort

# Add production environment with careful settings
./scripts/add-environment.sh prod --replicas 5 --no-auto-heal

# Clean up a specific per-app application
./scripts/cleanup-environments.sh dev-demo-app

# Clean up all applications (with confirmation)
./scripts/cleanup-environments.sh --all

# Dry run to see what would be deleted
./scripts/cleanup-environments.sh --all --dry-run

# Demo per-app hook behavior
./scripts/test-per-app-hooks.sh

# Reset ArgoCD to clean state
./scripts/reset-argocd.sh
```

### 📊 Monitoring & Status

| Script | Description |
|--------|-------------|
| `monitor-environments.sh` | Monitor sync status across all per-app applications |

**Usage Examples:**
```bash
# Show summary table
./scripts/monitor-environments.sh

# Show detailed information
./scripts/monitor-environments.sh --details

# Continuous monitoring (watch mode)
./scripts/monitor-environments.sh --watch
```

## 🔧 Script Features

### ✨ Common Features Across All Scripts

- **🎨 Colored Output**: Easy-to-read colored messages and status indicators
- **🛡️ Error Handling**: Comprehensive error checking and validation
- **📋 Help Documentation**: All scripts have `--help` for detailed usage
- **⚡ Prerequisites Checking**: Automatic validation of kubectl, cluster connectivity, etc.
- **🔒 Safety First**: Confirmation prompts for destructive operations

### 🌟 Advanced Features

| Feature | Scripts | Description |
|---------|---------|-------------|
| **Dry Run Mode** | `cleanup-environments.sh` | See what would happen without making changes |
| **Watch Mode** | `monitor-environments.sh` | Continuous monitoring with auto-refresh |
| **Force Mode** | `cleanup-environments.sh` | Skip confirmation prompts for automation |
| **Validation** | `argocd-helper.sh` | Check configuration integrity |
| **Auto-Detection** | All scripts | Automatically detect project structure and settings |

## 📋 Common Usage Patterns

### 🚀 Initial Setup
```bash
# 1. Install ArgoCD
./scripts/argocd-helper.sh install-argocd

# 2. Deploy your applications
./scripts/argocd-helper.sh deploy

# 3. Monitor status
./scripts/argocd-helper.sh status
```

### 🏗️ Adding New Environment
```bash
# 1. Add environment
./scripts/argocd-helper.sh add-env uat --replicas 3

# 2. Commit changes
git add environments/uat/ .argocd/uat/
git commit -m "Add UAT environment"
git push

# 3. Monitor deployment
./scripts/argocd-helper.sh monitor
```

### 🔍 Daily Operations
```bash
# Check status of all environments
./scripts/argocd-helper.sh status

# Force sync a specific application
./scripts/argocd-helper.sh sync dev-demo-app

# Port forward to an application
./scripts/argocd-helper.sh port-forward staging-api-service 8081

# View logs for an application
./scripts/argocd-helper.sh logs production-demo-app
```

### 🧹 Cleanup Operations
```bash
# Clean up specific application
./scripts/argocd-helper.sh cleanup dev-demo-app

# See what would be deleted (dry run)
./scripts/cleanup-environments.sh --all --dry-run

# Clean up everything
./scripts/cleanup-environments.sh --all --force
```

## 🔐 Making Scripts Executable

After cloning the repository, make the scripts executable:

```bash
chmod +x scripts/*.sh
```

Or individually:
```bash
chmod +x scripts/argocd-helper.sh
chmod +x scripts/install-argocd.sh
chmod +x scripts/deploy-applications.sh
chmod +x scripts/monitor-environments.sh
chmod +x scripts/add-environment.sh
chmod +x scripts/cleanup-environments.sh
chmod +x scripts/test-per-app-hooks.sh
chmod +x scripts/reset-argocd.sh
```

## 🛠️ Prerequisites

- **kubectl**: Configured to access your Kubernetes cluster
- **bash**: Version 4+ (included in macOS and most Linux distributions)
- **Standard tools**: `grep`, `awk`, `sed`, `base64` (usually pre-installed)

## 🆘 Getting Help

- **General help**: `./scripts/argocd-helper.sh help`
- **Specific script help**: `./scripts/<script-name>.sh --help`
- **Examples**: Check the examples section in each script's help output

## 🎯 Tips & Best Practices

1. **Always use the main helper**: Start with `./scripts/argocd-helper.sh` for the best experience
2. **Dry run first**: Use `--dry-run` with cleanup operations to avoid accidents
3. **Monitor deployments**: Use `--watch` mode when waiting for changes to apply
4. **Validate configs**: Run `./scripts/argocd-helper.sh validate` after making changes
5. **Use meaningful names**: Environment names should be lowercase, use hyphens for spaces

---

🎉 **Happy ArgoCD-ing with Selective Sync!** 🎉
