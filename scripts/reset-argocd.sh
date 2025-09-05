#!/bin/bash

# reset-argocd.sh
# Script to reset ArgoCD back to default state with no applications

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found"
        exit 1
    fi
}

# Delete all ApplicationSets
delete_applicationsets() {
    log_info "Deleting all ApplicationSets..."
    
    local appsets
    appsets=$(kubectl get applicationsets -n argocd -o name 2>/dev/null | wc -l || echo "0")
    
    if [ "$appsets" -gt 0 ]; then
        kubectl get applicationsets -n argocd -o name | while read -r appset; do
            local name
            name=$(echo "$appset" | cut -d'/' -f2)
            log_info "Deleting ApplicationSet: $name"
            kubectl delete "$appset" -n argocd
        done
        log_success "All ApplicationSets deleted"
    else
        log_info "No ApplicationSets found to delete"
    fi
}

# Delete all Applications
delete_applications() {
    log_info "Deleting all ArgoCD Applications..."
    
    local apps
    apps=$(kubectl get applications -n argocd -o name 2>/dev/null | wc -l || echo "0")
    
    if [ "$apps" -gt 0 ]; then
        kubectl get applications -n argocd -o name | while read -r app; do
            local name
            name=$(echo "$app" | cut -d'/' -f2)
            log_info "Deleting Application: $name"
            kubectl delete "$app" -n argocd
        done
        
        # Wait for applications to be fully deleted
        log_info "Waiting for applications to be fully deleted..."
        local timeout=120
        local elapsed=0
        
        while [ $elapsed -lt $timeout ]; do
            local remaining
            remaining=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
            if [ "$remaining" -eq 0 ]; then
                break
            fi
            log_info "Waiting for $remaining applications to be deleted..."
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        log_success "All Applications deleted"
    else
        log_info "No Applications found to delete"
    fi
}

# Clean up application namespaces
cleanup_app_namespaces() {
    log_info "Cleaning up application namespaces..."
    
    # Clean up old environment-based namespaces
    local old_namespaces=("argocd-demo-app-dev" "argocd-demo-app-staging" "argocd-demo-app-production")
    
    for ns in "${old_namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_info "Deleting namespace: $ns"
            kubectl delete namespace "$ns" --timeout=60s || log_warning "Timeout deleting $ns, it may still be terminating"
        fi
    done
    
    # Clean up per-app namespaces
    local per_app_namespaces=("dev-demo-app" "dev-api-service" "staging-demo-app" "staging-api-service" "production-demo-app" "production-api-service")
    
    for ns in "${per_app_namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_info "Deleting namespace: $ns"
            kubectl delete namespace "$ns" --timeout=60s || log_warning "Timeout deleting $ns, it may still be terminating"
        fi
    done
    
    # Clean up any other demo/test namespaces
    local other_namespaces
    other_namespaces=$(kubectl get namespaces -o name 2>/dev/null | grep -E "(demo|test|qa|uat)" | cut -d'/' -f2 || echo "")
    
    if [ -n "$other_namespaces" ]; then
        log_info "Found additional demo/test namespaces to clean up:"
        echo "$other_namespaces" | while read -r ns; do
            if [ -n "$ns" ]; then
                log_info "Deleting namespace: $ns"
                kubectl delete namespace "$ns" --timeout=60s || log_warning "Timeout deleting $ns, it may still be terminating"
            fi
        done
    fi
    
    log_success "Namespace cleanup completed"
}

# Wait for namespaces to be fully deleted
wait_for_namespace_cleanup() {
    log_info "Waiting for all namespaces to be fully terminated..."
    
    local timeout=180  # 3 minutes
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        local terminating
        terminating=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "(demo|test|qa|uat|Terminating)" | wc -l || echo "0")
        
        if [ "$terminating" -eq 0 ]; then
            log_success "All namespaces fully terminated"
            return 0
        fi
        
        log_info "Waiting for $terminating namespaces to terminate..."
        kubectl get namespaces --no-headers 2>/dev/null | grep Terminating || true
        sleep 10
        elapsed=$((elapsed + 10))
    done
    
    log_warning "Some namespaces may still be terminating after timeout"
}

# Show final status
show_status() {
    echo
    log_info "==================== FINAL STATUS ===================="
    echo
    
    log_info "ArgoCD Applications:"
    local apps
    apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$apps" -eq 0 ]; then
        echo "  ✅ No applications found"
    else
        kubectl get applications -n argocd
    fi
    
    echo
    log_info "ApplicationSets:"
    local appsets
    appsets=$(kubectl get applicationsets -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$appsets" -eq 0 ]; then
        echo "  ✅ No ApplicationSets found"
    else
        kubectl get applicationsets -n argocd
    fi
    
    echo
    log_info "Application Namespaces:"
    local app_namespaces
    app_namespaces=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "(demo|test|qa|uat)" | wc -l || echo "0")
    if [ "$app_namespaces" -eq 0 ]; then
        echo "  ✅ No application namespaces found"
    else
        kubectl get namespaces | grep -E "(demo|test|qa|uat)" || echo "  ✅ No application namespaces found"
    fi
    
    echo
    log_info "ArgoCD Core Status:"
    kubectl get pods -n argocd --no-headers | grep -E "(argocd-server|argocd-repo-server|argocd-application-controller)" | awk '{print "  " $1 ": " $3}'
    
    echo
    log_success "ArgoCD has been reset to default state!"
    echo
    echo "🎉 ArgoCD is now clean and ready for new applications"
    echo
    echo "📋 Next steps:"
    echo "   • You can now deploy new ApplicationSets or Applications"
    echo "   • Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   • Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 --decode"
}

# Main function
main() {
    echo
    log_info "============================================"
    log_info "         ArgoCD Reset Script"
    log_info "============================================"
    echo
    
    log_warning "This will delete ALL ArgoCD Applications, ApplicationSets, and associated namespaces!"
    read -p "Are you sure you want to continue? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
    
    echo
    
    check_kubectl
    delete_applicationsets
    delete_applications
    cleanup_app_namespaces
    wait_for_namespace_cleanup
    show_status
}

# Run main function
main "$@"
