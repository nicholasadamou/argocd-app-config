#!/bin/bash

# deploy-applications.sh
# Script to deploy the ApplicationSet and monitor all environments

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
APPLICATION_FILE="$PROJECT_ROOT/application.yaml"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if ArgoCD is installed
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found. Please install ArgoCD first."
        log_info "Run: ./scripts/install-argocd.sh"
        exit 1
    fi
    
    # Check if application.yaml exists
    if [ ! -f "$APPLICATION_FILE" ]; then
        log_error "application.yaml not found at $APPLICATION_FILE"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Deploy ApplicationSet
deploy_applicationset() {
    log_info "Deploying ApplicationSet..."
    
    kubectl apply -f "$APPLICATION_FILE"
    
    log_success "ApplicationSet deployed successfully"
}

# Wait for applications to be created
wait_for_applications() {
    log_info "Waiting for applications to be created by ApplicationSet..."
    
    local max_attempts=30
    local attempt=0
    local expected_apps=("argocd-demo-app-dev" "argocd-demo-app-staging" "argocd-demo-app-production")
    
    while [ $attempt -lt $max_attempts ]; do
        local found_apps=0
        
        for app in "${expected_apps[@]}"; do
            if kubectl get application "$app" -n argocd &> /dev/null; then
                ((found_apps++))
            fi
        done
        
        if [ $found_apps -eq ${#expected_apps[@]} ]; then
            log_success "All applications created successfully"
            return 0
        fi
        
        log_info "Found $found_apps/${#expected_apps[@]} applications, waiting... (attempt $((attempt+1))/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log_warning "Not all applications were created within the timeout period"
    return 1
}

# Show application status
show_application_status() {
    log_info "Checking application status..."
    echo
    
    # Get all applications
    echo "📋 ArgoCD Applications:"
    kubectl get applications -n argocd -o wide || true
    echo
    
    # Check specific applications
    local apps=("argocd-demo-app-dev" "argocd-demo-app-staging" "argocd-demo-app-production")
    
    for app in "${apps[@]}"; do
        echo "🔍 Application: $app"
        if kubectl get application "$app" -n argocd &> /dev/null; then
            local sync_status health_status
            sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
            
            echo "  Sync Status: $sync_status"
            echo "  Health Status: $health_status"
        else
            echo "  Status: Not found"
        fi
        echo
    done
}

# Show namespace status
show_namespace_status() {
    log_info "Checking namespace status..."
    echo
    
    local namespaces=("argocd-demo-app-dev" "argocd-demo-app-staging" "argocd-demo-app-production")
    
    for ns in "${namespaces[@]}"; do
        echo "🌐 Namespace: $ns"
        if kubectl get namespace "$ns" &> /dev/null; then
            echo "  Status: Created"
            echo "  Resources:"
            kubectl get all -n "$ns" --no-headers 2>/dev/null | wc -l | xargs echo "    Total resources:" || echo "    Total resources: 0"
        else
            echo "  Status: Not created yet"
        fi
        echo
    done
}

# Show helpful commands
show_helpful_commands() {
    echo
    log_info "Helpful commands:"
    echo
    echo "🔍 Monitor applications:"
    echo "  kubectl get applications -n argocd -w"
    echo
    echo "🔍 Check specific application:"
    echo "  kubectl describe application argocd-demo-app-dev -n argocd"
    echo
    echo "🌐 Access applications:"
    echo "  # Dev environment"
    echo "  kubectl port-forward svc/argocd-demo-app-service -n argocd-demo-app-dev 8080:8080"
    echo "  # Staging environment"
    echo "  kubectl port-forward svc/argocd-demo-app-service -n argocd-demo-app-staging 8081:8080"
    echo "  # Production environment"
    echo "  kubectl port-forward svc/argocd-demo-app-service -n argocd-demo-app-production 8082:8080"
    echo
    echo "🔄 Force sync an application:"
    echo "  kubectl patch application argocd-demo-app-dev -n argocd --type merge --patch '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"syncStrategy\":{\"apply\":{\"force\":true}}}}}'"
    echo
}

# Main function
main() {
    echo
    log_info "=========================================="
    log_info "    ApplicationSet Deployment Script"
    log_info "=========================================="
    echo
    
    check_prerequisites
    deploy_applicationset
    wait_for_applications
    
    echo
    log_info "=========================================="
    log_info "           Status Overview"
    log_info "=========================================="
    echo
    
    show_application_status
    show_namespace_status
    show_helpful_commands
    
    log_success "Deployment script completed!"
}

# Run main function
main "$@"
