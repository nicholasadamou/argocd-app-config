#!/bin/bash

# add-environment.sh
# Script to add a new environment to the selective sync setup

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Show help
show_help() {
    echo "Usage: $0 <environment_name> [OPTIONS]"
    echo
    echo "Add a new environment to the ArgoCD per-app selective sync setup"
    echo
    echo "Arguments:"
    echo "  environment_name    Name of the new environment (e.g., 'qa', 'uat', 'demo')"
    echo
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  -r, --replicas     Number of replicas (default: 2)"
    echo "  -s, --service-type Service type: ClusterIP, NodePort, LoadBalancer (default: ClusterIP)"
    echo "  --no-auto-heal     Disable automatic healing for this environment"
    echo "  --no-auto-sync     Disable automatic sync for this environment"
    echo
    echo "Examples:"
    echo "  $0 qa                           # Create QA environment with defaults"
    echo "  $0 uat --replicas 4             # Create UAT with 4 replicas"
    echo "  $0 demo --service-type NodePort # Create demo with NodePort service"
    echo "  $0 prod --no-auto-heal          # Create prod without auto-healing"
}

# Validate environment name
validate_environment_name() {
    local env_name=$1
    
    # Check if name contains only lowercase letters, numbers, and hyphens
    if [[ ! "$env_name" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Environment name must contain only lowercase letters, numbers, and hyphens"
        exit 1
    fi
    
    # Check if name is too long
    if [ ${#env_name} -gt 20 ]; then
        log_error "Environment name must be 20 characters or less"
        exit 1
    fi
    
    # Check if environment already exists (check for per-app structure)
    if [ -d "$PROJECT_ROOT/$env_name" ]; then
        log_error "Environment '$env_name' already exists"
        exit 1
    fi
    
    log_success "Environment name '$env_name' is valid"
}

# Create environment directory and manifests for per-app structure
create_environment_manifests() {
    local env_name=$1
    local replicas=$2
    local service_type=$3
    
    log_info "Creating per-app environment manifests for '$env_name'..."
    
    # Create environment directory with per-app subdirectories
    mkdir -p "$PROJECT_ROOT/$env_name/demo-app"
    mkdir -p "$PROJECT_ROOT/$env_name/api-service"
    
    # Create demo-app deployment.yaml
    cat > "$PROJECT_ROOT/$env_name/demo-app/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: argocd-demo-app
spec:
  selector:
    matchLabels:
      app: argocd-demo-app
  replicas: $replicas
  template:
    metadata:
      labels:
        app: argocd-demo-app
        environment: $env_name
    spec:
      containers:
      - name: argocd-demo-app
        image: nanajanashia/argocd-app:1.2
        ports:
        - containerPort: 8080
        env:
        - name: ENVIRONMENT
          value: "$env_name"
EOF

    # Add resource limits for production-like environments
    if [[ "$env_name" == "prod"* ]] || [[ "$env_name" == "production"* ]]; then
        cat >> "$PROJECT_ROOT/$env_name/demo-app/deployment.yaml" << EOF
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
EOF
    fi
    
    # Create demo-app service.yaml
    cat > "$PROJECT_ROOT/$env_name/demo-app/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: argocd-demo-app-service
spec:
  selector:
    app: argocd-demo-app
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  type: $service_type
EOF

    # Create api-service deployment.yaml
    local api_replicas=$((replicas > 1 ? replicas - 1 : 1))
    cat > "$PROJECT_ROOT/$env_name/api-service/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
spec:
  selector:
    matchLabels:
      app: api-service
  replicas: $api_replicas
  template:
    metadata:
      labels:
        app: api-service
        environment: $env_name
    spec:
      containers:
      - name: api-service
        image: nginx:1.21
        ports:
        - containerPort: 80
        env:
        - name: ENV
          value: "$env_name"
EOF

    # Add resource limits for production-like api-service
    if [[ "$env_name" == "prod"* ]] || [[ "$env_name" == "production"* ]]; then
        cat >> "$PROJECT_ROOT/$env_name/api-service/deployment.yaml" << EOF
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
EOF
    fi
    
    # Create api-service service.yaml
    cat > "$PROJECT_ROOT/$env_name/api-service/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api-service
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  type: ClusterIP
EOF

    log_success "Per-app environment manifests created"
}

# Create ArgoCD application definitions for per-app structure
create_argocd_applications() {
    local env_name=$1
    local auto_heal=$2
    local auto_sync=$3
    
    log_info "Creating ArgoCD per-app application definitions for '$env_name'..."
    
    # Create .argocd directories for each app
    mkdir -p "$PROJECT_ROOT/.argocd/$env_name-demo-app"
    mkdir -p "$PROJECT_ROOT/.argocd/$env_name-api-service"
    
    # Determine sync policy
    local automated_section=""
    if [ "$auto_sync" = "true" ]; then
        automated_section="    automated:"$'\n'"      selfHeal: $auto_heal"$'\n'"      prune: true"
    else
        automated_section="    # automated: false  # Manual sync required"
    fi
    
    # Create demo-app ArgoCD application
    cat > "$PROJECT_ROOT/.argocd/$env_name-demo-app/app.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $env_name-demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nicholasadamou/argocd-app-config.git
    targetRevision: HEAD
    path: $env_name/demo-app
  destination: 
    server: https://kubernetes.default.svc
    namespace: $env_name-demo-app
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
$automated_section
EOF

    # Create api-service ArgoCD application
    cat > "$PROJECT_ROOT/.argocd/$env_name-api-service/app.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $env_name-api-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/nicholasadamou/argocd-app-config.git
    targetRevision: HEAD
    path: $env_name/api-service
  destination: 
    server: https://kubernetes.default.svc
    namespace: $env_name-api-service
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
$automated_section
EOF

    log_success "Per-app ArgoCD application definitions created"
}

# Show summary
show_summary() {
    local env_name=$1
    local replicas=$2
    local service_type=$3
    local auto_heal=$4
    local auto_sync=$5
    
    echo
    log_success "Environment '$env_name' created successfully!"
    echo
    echo "Configuration Summary:"
    echo "  Environment:    $env_name"
    echo "  Replicas:       $replicas"
    echo "  Service Type:   $service_type"
    echo "  Auto Sync:      $auto_sync"
    echo "  Auto Heal:      $auto_heal"
    echo
    echo "Files created:"
    echo "  $env_name/demo-app/deployment.yaml"
    echo "  $env_name/demo-app/service.yaml"
    echo "  $env_name/api-service/deployment.yaml"
    echo "  $env_name/api-service/service.yaml"
    echo "  .argocd/$env_name-demo-app/app.yaml"
    echo "  .argocd/$env_name-api-service/app.yaml"
    echo
    echo "Applications created:"
    echo "  - $env_name-demo-app"
    echo "  - $env_name-api-service"
    echo
    echo "Next steps:"
    echo "  1. Review and customize the generated manifests"
    echo "  2. Commit and push the changes:"
    echo "     git add $env_name/ .argocd/$env_name-*/"
    echo "     git commit -m \"Add $env_name environment with per-app structure\""
    echo "     git push"
    echo "  3. The ApplicationSet will automatically detect and deploy the new per-app applications"
    echo
    echo "Monitor the deployment with:"
    echo "  ./scripts/monitor-environments.sh"
    echo
}

# Main function
main() {
    local environment_name=""
    local replicas=2
    local service_type="ClusterIP"
    local auto_heal="true"
    local auto_sync="true"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--replicas)
                if [[ -n "${2-}" && "$2" =~ ^[0-9]+$ ]]; then
                    replicas=$2
                    shift 2
                else
                    log_error "Replicas must be a positive number"
                    exit 1
                fi
                ;;
            -s|--service-type)
                if [[ -n "${2-}" && "$2" =~ ^(ClusterIP|NodePort|LoadBalancer)$ ]]; then
                    service_type=$2
                    shift 2
                else
                    log_error "Service type must be one of: ClusterIP, NodePort, LoadBalancer"
                    exit 1
                fi
                ;;
            --no-auto-heal)
                auto_heal="false"
                shift
                ;;
            --no-auto-sync)
                auto_sync="false"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$environment_name" ]; then
                    environment_name=$1
                    shift
                else
                    log_error "Multiple environment names specified"
                    show_help
                    exit 1
                fi
                ;;
        esac
    done
    
    # Check if environment name was provided
    if [ -z "$environment_name" ]; then
        log_error "Environment name is required"
        show_help
        exit 1
    fi
    
    echo
    log_info "=========================================="
    log_info "        Add New Environment Script"
    log_info "=========================================="
    echo
    
    validate_environment_name "$environment_name"
    create_environment_manifests "$environment_name" "$replicas" "$service_type"
    create_argocd_applications "$environment_name" "$auto_heal" "$auto_sync"
    show_summary "$environment_name" "$replicas" "$service_type" "$auto_heal" "$auto_sync"
}

# Run main function
main "$@"
