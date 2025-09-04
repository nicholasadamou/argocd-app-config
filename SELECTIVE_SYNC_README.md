# Selective Sync ArgoCD Configuration

This repository has been restructured to implement **selective syncing** in ArgoCD. This means that changes to one environment will only trigger syncs for that specific environment, not all environments.

## Structure

```
├── application.yaml              # ApplicationSet that manages all apps
├── .argocd/                     # ArgoCD application definitions
│   ├── dev/
│   │   └── app.yaml            # Dev application definition
│   ├── staging/
│   │   └── app.yaml            # Staging application definition
│   └── production/
│       └── app.yaml            # Production application definition
├── dev/                        # Dev environment manifests
│   ├── deployment.yaml
│   └── service.yaml
├── staging/                    # Staging environment manifests
│   ├── deployment.yaml
│   └── service.yaml
└── production/                 # Production environment manifests
    ├── deployment.yaml
    └── service.yaml
```

## How Selective Sync Works

### ApplicationSet with Directory Generator
The root `application.yaml` contains an ApplicationSet that uses a directory generator to scan `.argocd/*` and create individual ArgoCD Applications for each environment.

### Path-Based Targeting
Each generated application targets a specific path:
- **dev** app watches changes in the `dev/` directory only
- **staging** app watches changes in the `staging/` directory only  
- **production** app watches changes in the `production/` directory only

### Benefits
1. **Isolated Deployments**: Changes to dev configs won't trigger production syncs
2. **Reduced Noise**: No unnecessary sync operations for unchanged environments
3. **Independent Scaling**: Each environment can have different sync policies
4. **Selective Testing**: Post-sync hooks will only trigger for the changed environment

## Usage

1. **Deploy the ApplicationSet**: Apply `application.yaml` to your ArgoCD instance
2. **Make Environment-Specific Changes**: Modify files in `dev/`, `staging/`, or `production/`
3. **Observe Selective Syncing**: Only the affected environment will sync

## Example Scenarios

### Scenario 1: Update Dev Environment
```bash
# Modify dev deployment
vim dev/deployment.yaml
git add dev/deployment.yaml
git commit -m "Update dev replicas"
git push
```
**Result**: Only the dev application will sync and trigger post-sync hooks.

### Scenario 2: Update Production Environment
```bash
# Modify production service
vim production/service.yaml  
git add production/service.yaml
git commit -m "Change production service type"
git push
```
**Result**: Only the production application will sync.

### Scenario 3: Update Multiple Environments
```bash
# Modify both staging and production
vim staging/deployment.yaml
vim production/deployment.yaml
git add staging/ production/
git commit -m "Update staging and production"
git push
```
**Result**: Both staging and production applications will sync, but dev remains untouched.

## Post-Sync Hooks

With this structure, you can add environment-specific post-sync hooks to each application definition in `.argocd/*/app.yaml`. For example:

```yaml
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      selfHeal: true
      prune: true
  # Add post-sync hook for testing
  operation:
    sync:
      hooks:
      - name: test-hook
        kind: Job
        template: |
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: post-sync-test
          spec:
            template:
              spec:
                containers:
                - name: test
                  image: curlimages/curl
                  command: ["curl", "-f", "http://argocd-demo-app-service:8080"]
                restartPolicy: Never
```

This ensures tests only run when the specific environment actually changes.
