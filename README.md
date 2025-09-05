# ArgoCD Application Configuration with Per-App Hooks

This repository contains Kubernetes manifests and ArgoCD application configuration for deploying applications using GitOps practices with ArgoCD. It implements **per-application selective syncing** with dedicated post-sync hooks, ensuring that changes to a specific app only trigger syncs and validations for that individual application.

> 📖 **For detailed information about per-app selective syncing**, see [SELECTIVE_SYNC_README.md](SELECTIVE_SYNC_README.md)

## 📁 Repository Structure

```
.
├── README.md                           # This documentation
├── SELECTIVE_SYNC_README.md            # Detailed per-app sync documentation
├── application.yaml                    # ArgoCD ApplicationSet (manages all apps)
├── test-per-app-hooks.sh              # Demo script showing per-app hook behavior
├── .argocd/                           # Per-app ArgoCD application definitions
│   ├── dev-demo-app/
│   │   └── app.yaml                   # Dev demo-app with custom post-sync hook
│   ├── dev-api-service/
│   │   └── app.yaml                   # Dev api-service with custom post-sync hook
│   ├── staging-demo-app/
│   │   └── app.yaml                   # Staging demo-app with enhanced validation
│   ├── staging-api-service/
│   │   └── app.yaml                   # Staging api-service with validation
│   ├── production-demo-app/
│   │   └── app.yaml                   # Production demo-app with comprehensive checks
│   └── production-api-service/
│       └── app.yaml                   # Production api-service with load balancer validation
├── dev/                               # Development environment manifests
│   ├── demo-app/                      # Demo application
│   │   ├── deployment.yaml           # Kubernetes Deployment
│   │   └── service.yaml              # Kubernetes Service
│   └── api-service/                   # API service application
│       ├── deployment.yaml           # Kubernetes Deployment
│       └── service.yaml              # Kubernetes Service
├── staging/                           # Staging environment manifests
│   ├── demo-app/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── api-service/
│       ├── deployment.yaml
│       └── service.yaml
├── production/                        # Production environment manifests
│   ├── demo-app/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── api-service/
│       ├── deployment.yaml
│       └── service.yaml
└── scripts/                           # Helpful management scripts
    ├── README.md                      # Scripts documentation
    ├── argocd-helper.sh               # Main helper script (recommended)
    ├── install-argocd.sh              # Install ArgoCD
    ├── deploy-applications.sh         # Deploy ApplicationSet
    ├── monitor-environments.sh        # Monitor environments
    ├── add-environment.sh             # Add new environments
    └── cleanup-environments.sh        # Clean up environments
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

This file defines an ApplicationSet that manages multiple applications with **per-app selective syncing**:

- **Generator**: Uses directory generator to scan for individual app directories (`dev/demo-app/`, `dev/api-service/`, etc.)
- **Source Repository**: Points to this GitHub repository
- **Per-App Targeting**: Each ArgoCD Application watches only its specific app directory
- **Namespaces**: Each app deploys to its own namespace (`dev-demo-app`, `dev-api-service`, etc.)
- **Individual Sync Policies**: Each app can have different sync policies and automation settings

### Per-App Manifests

- **Demo App**: Web application with different replica counts per environment (dev: 2, staging: 3, production: 5)
- **API Service**: Backend service with environment-specific configurations and scaling
- **Environment Variations**: Each environment has different resource limits, service types, and configurations

### Per-App Post-Sync Hooks

Each individual application has its own custom post-sync validation:

- **Dev Apps**: Basic health checks with quick validation
- **Staging Apps**: Enhanced validation with longer wait times
- **Production Apps**: Comprehensive validation with multiple checks, longer timeouts, and more retry attempts

### Per-App Selective Sync Benefits

✅ **Ultimate Isolation**: Changes to one app won't trigger syncs for any other app

✅ **Granular Control**: Each app has its own sync policies, hooks, and validation logic

✅ **Resource Efficiency**: Only the changed app runs validation/testing

✅ **Targeted Debugging**: Hook failures are clearly tied to specific apps

✅ **Custom Validation**: Each app type can have different testing requirements

✅ **Parallel Execution**: Multiple apps can validate simultaneously when needed

## 🎯 Usage

### Per-App Selective Updates

1. **Make changes** to manifests in a specific app directory (`dev/demo-app/`, `production/api-service/`, etc.)
2. **Commit and push** changes to this repository
3. **Only the affected app syncs** - all other apps remain untouched
4. **Only that app's post-sync hook runs** - targeted validation
5. **Monitor** the deployment in the ArgoCD UI

### Example Workflows

```bash
# Update only dev demo-app
vim dev/demo-app/deployment.yaml
git add dev/demo-app/
git commit -m "Scale dev demo-app to 3 replicas"
git push
# Result: Only dev-demo-app syncs and runs dev-demo-app-post-sync hook
#         dev-api-service and all other apps remain untouched

# Update only production api-service
vim production/api-service/deployment.yaml
git add production/api-service/
git commit -m "Update production api-service image"
git push
# Result: Only production-api-service syncs and runs comprehensive validation
#         production-demo-app and all other apps remain untouched

# Update same app across environments
vim staging/demo-app/service.yaml
vim production/demo-app/service.yaml
git add staging/demo-app/ production/demo-app/
git commit -m "Update demo-app service configuration"
git push
# Result: staging-demo-app and production-demo-app sync independently
#         All api-service apps in all environments remain untouched
```

### 🎥 Demo Per-App Hook Behavior

```bash
# Run the demo script to see exactly how per-app hooks work
./test-per-app-hooks.sh
```

This script shows you exactly which applications sync and which post-sync hooks run for different change scenarios.

## 📊 Monitoring

### Check Application Status

```bash
# Check all ArgoCD applications managed by the ApplicationSet
kubectl get applications -n argocd

# Check specific app deployments
kubectl get all -n dev-demo-app
kubectl get all -n dev-api-service
kubectl get all -n staging-demo-app
kubectl get all -n staging-api-service
kubectl get all -n production-demo-app
kubectl get all -n production-api-service
```

### Monitor Per-App Post-Sync Hooks

```bash
# Check post-sync hook jobs for specific apps
kubectl get jobs -n dev-demo-app
kubectl get jobs -n production-api-service

# Check hook execution logs
kubectl logs -n dev-demo-app job/dev-demo-app-post-sync
kubectl logs -n production-api-service job/production-api-service-validation

# Watch hook execution in real-time
kubectl logs -f -n staging-demo-app job/staging-demo-app-post-sync
```

### Access Applications

```bash
# Access demo-app in different environments
kubectl port-forward svc/argocd-demo-app-service -n dev-demo-app 8080:8080
kubectl port-forward svc/argocd-demo-app-service -n staging-demo-app 8081:8080
kubectl port-forward svc/argocd-demo-app-service -n production-demo-app 8082:8080

# Access api-service in different environments
kubectl port-forward svc/api-service -n dev-api-service 8090:80
kubectl port-forward svc/api-service -n staging-api-service 8091:80
kubectl port-forward svc/api-service -n production-api-service 8092:80
```

## 🎯 Per-App Selective Sync in Action

This repository implements **per-application selective syncing** - the ultimate improvement over traditional GitOps setups:

| Traditional Approach | Environment-Level Selective Sync | **Per-App Selective Sync (This Repo)** |
|---------------------|----------------------------------|----------------------------------------|
| ❌ Single app watches entire repo | ✅ Multiple apps watch environment paths | 🎆 **Each app watches only its own path** |
| ❌ Changes anywhere trigger all syncs | ✅ Only affected environments sync | 🎆 **Only affected app syncs** |
| ❌ All hooks fire on any change | ✅ Environment-specific hooks only | 🎆 **App-specific hooks only** |
| ❌ High resource usage and noise | ✅ Moderate efficiency | 🎆 **Maximum efficiency and precision** |
| ❌ Difficult debugging | ✅ Environment-level debugging | 🎆 **App-level precision debugging** |

### 🎆 Example: The Power of Per-App Hooks

**Scenario**: You have 10 microservices across 3 environments (30 total applications)

- **Traditional**: Update 1 service → 30 apps sync + 30 post-sync hooks run 😱
- **Environment-Level**: Update 1 service → 3 apps sync + 3 hooks run 😐  
- **Per-App (This Repo)**: Update 1 service → 1 app syncs + 1 hook runs 🎉

> 📚 **Learn more**: See [SELECTIVE_SYNC_README.md](SELECTIVE_SYNC_README.md) for detailed implementation guide

## 🛠️ Helpful Scripts

This repository includes a comprehensive set of scripts to make managing your ArgoCD setup easy:

### 🎯 Quick Commands

```bash
# Make scripts executable (first time only)
chmod +x scripts/*.sh
chmod +x test-per-app-hooks.sh

# Demo per-app hook behavior
./test-per-app-hooks.sh

# Main helper script (shows all available commands)
./scripts/argocd-helper.sh help

# Quick status check for all apps
./scripts/argocd-helper.sh status

# Monitor all applications
./scripts/argocd-helper.sh monitor

# Add a new environment (will create apps for each service)
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

## 🎆 Per-App Features Highlight

This setup provides the ultimate GitOps granularity:

### 🎯 Individual Application Control
- **6 separate ArgoCD Applications**: `dev-demo-app`, `dev-api-service`, `staging-demo-app`, `staging-api-service`, `production-demo-app`, `production-api-service`
- **Independent sync policies**: Dev apps auto-heal, production apps require manual approval for safety
- **Isolated namespaces**: Each app deploys to its own Kubernetes namespace

### 🔧 Custom Post-Sync Hooks
- **Dev applications**: Basic health checks (10s wait, 3 retries)
- **Staging applications**: Enhanced validation (15s wait, more comprehensive checks)
- **Production applications**: Comprehensive validation (30s wait, 5 retries, multiple health checks)

### 🚀 Real-World Benefits
- **💰 Cost Savings**: No unnecessary compute for unrelated validations
- **⚡ Speed**: Only changed apps validate, dramatically faster deployment feedback
- **🎯 Precision**: Failures are immediately tied to specific apps
- **🔧 Flexibility**: Each app can have completely different validation logic
- **🔄 Parallel Processing**: Multiple app changes can validate simultaneously
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
