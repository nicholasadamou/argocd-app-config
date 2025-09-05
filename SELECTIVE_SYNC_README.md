# Per-App ArgoCD Configuration with Selective Post-Sync Hooks

This repository implements **per-application selective syncing** in ArgoCD. This means that changes to a specific application will only trigger syncs and post-sync hooks for that individual application, providing ultimate granularity and isolation.

## Structure

```
├── application.yaml                    # ApplicationSet that manages all apps
├── apps/                              # Per-app ArgoCD application definitions
│   ├── dev/
│   │   ├── demo-app.yaml              # Dev demo-app application
│   │   └── api-service.yaml           # Dev api-service application
│   ├── staging/
│   │   ├── demo-app.yaml              # Staging demo-app application
│   │   └── api-service.yaml           # Staging api-service application
│   └── production/
│       ├── demo-app.yaml              # Production demo-app application
│       └── api-service.yaml           # Production api-service application
└── environments/                      # Environment-specific manifests
    ├── dev/                          # Dev environment manifests
    │   ├── demo-app/
    │   │   ├── deployment.yaml
    │   │   └── service.yaml
    │   └── api-service/
    │       ├── deployment.yaml
    │       └── service.yaml
    ├── staging/                      # Staging environment manifests
    │   ├── demo-app/
    │   │   ├── deployment.yaml
    │   │   └── service.yaml
    │   └── api-service/
    │       ├── deployment.yaml
    │       └── service.yaml
    └── production/                   # Production environment manifests
        ├── demo-app/
        │   ├── deployment.yaml
        │   └── service.yaml
        └── api-service/
            ├── deployment.yaml
            └── service.yaml
```

## How Per-App Selective Sync Works

### ApplicationSet with Directory Generator
The root `application.yaml` contains an ApplicationSet that uses a directory generator to scan for individual app directories and create separate ArgoCD Applications for each app in each environment.

### Per-App Path Targeting
Each generated application targets a specific app path:
- **dev-demo-app** watches changes in `environments/dev/demo-app/` directory only
- **dev-api-service** watches changes in `environments/dev/api-service/` directory only  
- **staging-demo-app** watches changes in `environments/staging/demo-app/` directory only
- **staging-api-service** watches changes in `environments/staging/api-service/` directory only
- **production-demo-app** watches changes in `environments/production/demo-app/` directory only
- **production-api-service** watches changes in `environments/production/api-service/` directory only

### Benefits
1. **Ultimate Isolation**: Changes to one app won't trigger syncs for any other app
2. **Granular Control**: Each individual app has its own sync policies and hooks
3. **Resource Efficiency**: Only the changed app runs validation/testing
4. **Independent Scaling**: Apps can have different deployment strategies
5. **Targeted Debugging**: Hook failures are tied to specific apps, not environments
6. **Per-App Testing**: Custom validation logic for each application type

## Usage

1. **Deploy the ApplicationSet**: Apply `application.yaml` to your ArgoCD instance
2. **Make App-Specific Changes**: Modify files in specific app directories
3. **Observe Per-App Selective Syncing**: Only the affected app will sync

## Example Scenarios

### Scenario 1: Update Only Dev Demo-App
```bash
# Modify only the dev demo-app
vim environments/dev/demo-app/deployment.yaml
git add environments/dev/demo-app/deployment.yaml
git commit -m "Update dev demo-app replicas"
git push
```
**Result**: Only `dev-demo-app` syncs and runs `dev-demo-app-post-sync` hook. All other apps (including `dev-api-service`) remain untouched.

### Scenario 2: Update Production API Service
```bash
# Modify only production api-service
vim environments/production/api-service/deployment.yaml  
git add environments/production/api-service/deployment.yaml
git commit -m "Scale production api-service"
git push
```
**Result**: Only `production-api-service` syncs and runs `production-api-service-validation` hook with enhanced production checks.

### Scenario 3: Update Same App Across Environments
```bash
# Modify demo-app in both staging and production
vim environments/staging/demo-app/deployment.yaml
vim environments/production/demo-app/deployment.yaml
git add environments/staging/demo-app/ environments/production/demo-app/
git commit -m "Update demo-app across environments"
git push
```
**Result**: Both `staging-demo-app` and `production-demo-app` sync independently. API services in all environments remain untouched.

### Scenario 4: Update Multiple Apps in One Environment
```bash
# Update both apps in dev environment
vim environments/dev/demo-app/service.yaml
vim environments/dev/api-service/deployment.yaml
git add environments/dev/
git commit -m "Update dev services"
git push
```
**Result**: Both `dev-demo-app` and `dev-api-service` sync independently, each running their specific post-sync hooks.

## Environment-Specific Post-Sync Hooks

With this structure, each application has its own post-sync hooks that only execute when that specific environment changes. This ensures:

1. **Isolated Testing**: Only the updated environment runs validation
2. **Resource Efficiency**: No unnecessary test jobs across all environments
3. **Environment-Specific Logic**: Each environment can have different validation requirements

### Implementation

Each application in `apps/*/` contains environment-specific hooks:

```yaml
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      selfHeal: true
      prune: true
  # Environment-specific post-sync hook
  operation:
    sync:
      hooks:
      - name: env-post-sync-test
        argocd.argoproj.io/hook: PostSync
        argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
        manifest: |
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: env-post-sync-test
            namespace: argocd-demo-app-{environment}
          spec:
            template:
              spec:
                containers:
                - name: test
                  image: curlimages/curl
                  command: 
                  - /bin/sh
                  - -c
                  - |
                    echo "Running post-sync tests for {ENVIRONMENT}"
                    curl -f http://argocd-demo-app-service:8080/health
                    echo "Deployment verified successfully!"
                restartPolicy: Never
            backoffLimit: 3
```

### How It Works

- **Dev Changes**: Only `dev-post-sync-test` job runs
- **Staging Changes**: Only `staging-post-sync-test` job runs  
- **Production Changes**: Only `production-post-sync-validation` job runs with enhanced checks

This ensures tests and validations only run when the specific environment actually changes.

## 🔄 Reset to Clean State

If you need to start fresh or migrate from the old structure, use the reset script:

```bash
./scripts/reset-argocd.sh
```

### Reset Script Features:
- **Safe cleanup**: Removes all Applications and ApplicationSets
- **Namespace cleanup**: Deletes all application namespaces
- **Preserves core**: Keeps ArgoCD server, controller, and configuration intact
- **Fresh start**: Ready for new per-app deployments

### Use Cases:
- 📦 **Migration**: Moving from environment-based to per-app structure  
- 🧹 **Cleanup**: Remove test applications and start fresh
- 🛮 **Troubleshooting**: Fix stuck or corrupted applications
- 🔄 **Reset**: Return to baseline state for new experiments
