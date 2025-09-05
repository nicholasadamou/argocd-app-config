#!/bin/bash

# install-argocd.sh
# Script to install ArgoCD on a Kubernetes cluster

set -euo pipefail

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

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    log_info "kubectl found: $(kubectl version --client --short)"
}

# Check if we can connect to the cluster
check_cluster() {
    log_info "Checking cluster connectivity..."
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Please ensure kubectl is configured correctly"
        exit 1
    fi
    log_success "Connected to cluster: $(kubectl config current-context)"
}

# Install ArgoCD
install_argocd() {
    log_info "Installing ArgoCD..."
    
    # Create namespace
    log_info "Creating argocd namespace..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD
    log_info "Installing ArgoCD components..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    log_info "Waiting for ArgoCD server to be ready (timeout: 300s)..."
    kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    
    log_success "ArgoCD installed successfully!"
}

# Get ArgoCD admin password
get_admin_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    # Wait for the secret to be created
    log_info "Waiting for admin secret to be created..."
    kubectl wait --for=condition=complete --timeout=60s -n argocd --selector=app.kubernetes.io/name=argocd-server-init job || true
    
    # Get the password
    local password
    password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 --decode 2>/dev/null || echo "")
    
    if [ -n "$password" ]; then
        echo
        log_success "ArgoCD Admin Credentials:"
        echo "  Username: admin"
        echo "  Password: $password"
        echo
        log_warning "Please save these credentials and change the password after first login!"
    else
        log_warning "Could not retrieve admin password automatically."
        log_info "You can get it manually with:"
        echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 --decode"
    fi
}

# Show access information
show_access_info() {
    echo
    log_info "To access ArgoCD UI:"
    echo "  1. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  2. Open browser: https://localhost:8080"
    echo "  3. Accept the self-signed certificate"
    echo
    log_info "To access ArgoCD CLI:"
    echo "  1. Download CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    echo "  2. Login: argocd login localhost:8080"
    echo
}

# Main function
main() {
    echo
    log_info "=========================================="
    log_info "       ArgoCD Installation Script"
    log_info "=========================================="
    echo
    
    check_kubectl
    check_cluster
    install_argocd
    get_admin_password
    show_access_info
    
    log_success "ArgoCD installation completed!"
}

# Run main function
main "$@"
