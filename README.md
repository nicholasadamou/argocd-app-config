# ArgoCD Application Configuration

This repository contains Kubernetes manifests and ArgoCD application configuration for deploying applications using GitOps practices with ArgoCD. It implements **selective syncing** to ensure that changes to one environment only trigger syncs for that specific environment.

> 📖 **For detailed information about selective syncing**, see [SELECTIVE_SYNC_README.md](SELECTIVE_SYNC_README.md)

## 📁 Repository Structure

```
.
├── README.md                    # This documentation
├── SELECTIVE_SYNC_README.md     # Detailed selective sync documentation
├── application.yaml             # ArgoCD ApplicationSet (manages all environments)
├── .argocd/                     # ArgoCD application definitions
│   ├── dev/app.yaml            # Dev application definition
│   ├── staging/app.yaml        # Staging application definition
│   └── production/app.yaml     # Production application definition
├── dev/                        # Development environment manifests
│   ├── deployment.yaml         # Kubernetes Deployment
│   └── service.yaml           # Kubernetes Service
├── staging/                    # Staging environment manifests
│   ├── deployment.yaml         # Kubernetes Deployment
│   └── service.yaml           # Kubernetes Service
├── production/                 # Production environment manifests
│   ├── deployment.yaml         # Kubernetes Deployment
│   └── service.yaml           # Kubernetes Service
└── scripts/                    # Helpful management scripts
    ├── README.md              # Scripts documentation
    ├── argocd-helper.sh       # Main helper script (recommended)
    ├── install-argocd.sh      # Install ArgoCD
    ├── deploy-applications.sh # Deploy ApplicationSet
    ├── monitor-environments.sh # Monitor environments
    ├── add-environment.sh     # Add new environments
    └── cleanup-environments.sh # Clean up environments
```

## 🚀 What is ArgoCD?

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It follows the GitOps pattern of using Git repositories as the source of truth for defining the desired application state.

## 📋 Prerequisites

- Kubernetes cluster (local or remote)
- `kubectl` configured to access your cluster
- ArgoCD installed on your cluster

## 🛠️ Installation & Setup

### 1. Install ArgoCD

```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 2. Access ArgoCD UI

```bash
# Get ArgoCD services
kubectl get svc -n argocd

# Port forward to access UI locally
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open your browser and navigate to `https://localhost:8080`

### 3. Get Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo
```

**Login Credentials:**
- Username: `admin`
- Password: (output from the command above)

### 4. Deploy ApplicationSet

#### Option A: Using the Helper Script (Recommended)
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Deploy ApplicationSet and monitor creation
./scripts/argocd-helper.sh deploy
```

#### Option B: Manual Deployment
```bash
# Apply the ArgoCD ApplicationSet
kubectl apply -f application.yaml
```

## 🔧 Configuration Details

### ArgoCD ApplicationSet (`application.yaml`)

This file defines an ApplicationSet that manages multiple applications with selective syncing:

- **Generator**: Uses directory generator to scan `.argocd/*` for application definitions
- **Source Repository**: Points to this GitHub repository
- **Per-Environment Targeting**: Each environment watches only its specific directory
- **Namespaces**: Each environment deploys to its own namespace (`argocd-demo-app-{env}`)
- **Sync Policy**: Automated with environment-specific policies

### Environment-Specific Manifests

- **Dev Environment** (`dev/`): 2 replicas, basic configuration
- **Staging Environment** (`staging/`): 3 replicas, environment labels  
- **Production Environment** (`production/`): 5 replicas, resource limits, LoadBalancer service

### Selective Sync Benefits

✅ **Isolated Deployments**: Changes to dev won't trigger production syncs  
✅ **Reduced Noise**: No unnecessary sync operations  
✅ **Environment-Specific Hooks**: Post-sync tests only run for changed environments

## 🎯 Usage

### Selective Environment Updates

1. **Make changes** to manifests in a specific environment directory (`dev/`, `staging/`, or `production/`)
2. **Commit and push** changes to this repository
3. **Only the affected environment syncs** - other environments remain untouched
4. **Monitor** the deployment in the ArgoCD UI

### Example Workflows

```bash
# Update only development environment
vim dev/deployment.yaml
git add dev/
git commit -m "Update dev replicas to 3"
git push
# Result: Only dev application syncs

# Update multiple environments
vim staging/deployment.yaml
vim production/service.yaml  
git add staging/ production/
git commit -m "Update staging and production"
git push
# Result: Both staging and production sync, dev untouched
```

## 📊 Monitoring

### Check Application Status

```bash
# Check all ArgoCD applications managed by the ApplicationSet
kubectl get applications -n argocd

# Check specific environment deployments
kubectl get all -n argocd-demo-app-dev
kubectl get all -n argocd-demo-app-staging  
kubectl get all -n argocd-demo-app-production
```

### Access Applications

```bash
# Access development environment
kubectl port-forward svc/argocd-demo-app-service -n argocd-demo-app-dev 8080:8080

# Access staging environment  
kubectl port-forward svc/argocd-demo-app-service -n argocd-demo-app-staging 8081:8080

# Access production environment
kubectl port-forward svc/argocd-demo-app-service -n argocd-demo-app-production 8082:8080
```

## 🎯 Selective Sync in Action

This repository implements **selective syncing** - a key improvement over traditional GitOps setups:

| Traditional Approach | Selective Sync Approach |
|---------------------|-------------------------|
| ❌ Single application watches entire repo | ✅ Multiple applications watch specific paths |
| ❌ Changes anywhere trigger all syncs | ✅ Only affected environments sync |
| ❌ All post-sync hooks fire on any change | ✅ Environment-specific hooks only |
| ❌ Higher resource usage and noise | ✅ Efficient, targeted deployments |
```

> 📚 **Learn more**: See [SELECTIVE_SYNC_README.md](SELECTIVE_SYNC_README.md) for detailed implementation guide

## 🛠️ Helpful Scripts

This repository includes a comprehensive set of scripts to make managing your ArgoCD setup easy:

### 🎯 Quick Commands

```bash
# Make scripts executable (first time only)
chmod +x scripts/*.sh

# Main helper script (shows all available commands)
./scripts/argocd-helper.sh help

# Quick status check
./scripts/argocd-helper.sh status

# Monitor all environments
./scripts/argocd-helper.sh monitor

# Add a new environment
./scripts/argocd-helper.sh add-env qa --replicas 3
```

### 📁 Available Scripts

| Script | Purpose | Example |
|--------|---------|----------|
| **`argocd-helper.sh`** | **Main entry point** | `./scripts/argocd-helper.sh help` |
| `install-argocd.sh` | Install ArgoCD | `./scripts/install-argocd.sh` |
| `deploy-applications.sh` | Deploy ApplicationSet | `./scripts/deploy-applications.sh` |
| `monitor-environments.sh` | Monitor sync status | `./scripts/monitor-environments.sh --watch` |
| `add-environment.sh` | Add new environment | `./scripts/add-environment.sh qa --replicas 3` |
| `cleanup-environments.sh` | Clean up resources | `./scripts/cleanup-environments.sh staging` |

> 📄 **Full documentation**: See [scripts/README.md](scripts/README.md) for complete usage guide
## 🔄 GitOps Workflow

1. **Developer** makes changes to application code
2. **CI/CD** builds and pushes new container image
3. **Update** image tag in environment-specific `deployment.yaml`
4. **ArgoCD** detects changes and syncs **only the affected environment**
5. **Application** is updated with zero impact on other environments

## 🛡️ Security Best Practices

- Change the default admin password after first login
- Use RBAC to control access to applications
- Enable SSO for production environments
- Regularly update ArgoCD to the latest version

## 🔗 Useful Links

- **Config Repository**: [https://github.com/nicholasadamou/argocd-app-config](https://github.com/nicholasadamou/argocd-app-config)
- **Docker Repository**: [https://hub.docker.com/repository/docker/nicholasadamou/argocd-app](https://hub.docker.com/repository/docker/nicholasadamou/argocd-app)
- **ArgoCD Documentation**: [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)
- **ArgoCD Getting Started**: [https://argo-cd.readthedocs.io/en/stable/getting_started/](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- **GitOps Principles**: [https://www.gitops.tech/](https://www.gitops.tech/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
