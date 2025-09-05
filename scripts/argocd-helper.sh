#!/bin/bash

# argocd-helper.sh
# Main helper script for ArgoCD selective sync operations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Show main help
show_help() {
    echo -e "${PURPLE}ArgoCD Selective Sync Helper${NC}"
    echo
    echo "A collection of scripts to manage ArgoCD applications with selective syncing"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo "  $0 <command> [arguments]"
    echo
    echo -e "${CYAN}Available Commands:${NC}"
    echo
    echo -e "${YELLOW}Setup & Installation:${NC}"
    echo "  install-argocd         Install ArgoCD on the current cluster"
    echo "  deploy                 Deploy the ApplicationSet and all applications"
    echo
    echo -e "${YELLOW}Application Management:${NC}"
    echo "  add-env <name>         Add a new environment (creates per-app structure)"
    echo "  list-apps              List all configured applications"
    echo "  monitor                Monitor all applications"
    echo "  cleanup [app]          Clean up applications"
    echo
    echo -e "${YELLOW}Monitoring & Status:${NC}"
    echo "  status                 Show status of all applications"
    echo "  sync <app>             Force sync a specific application"
    echo "  logs <app>             Show logs for an application"
    echo
    echo -e "${YELLOW}Utilities:${NC}"
    echo "  port-forward <app>     Port forward to an application"
    echo "  validate               Validate configuration files"
    echo "  help                   Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 install-argocd"
    echo "  $0 deploy"
    echo "  $0 add-env qa --replicas 3"
    echo "  $0 monitor --watch"
    echo "  $0 status"
    echo "  $0 port-forward dev-demo-app"
    echo
    echo -e "${CYAN}For detailed help on a specific command:${NC}"
    echo "  $0 <command> --help"
    echo
}

# List applications
list_applications() {
    log_info "Configured per-app applications:"
    echo
    
    if [ ! -d "$PROJECT_ROOT/apps" ]; then
        log_warning "No apps directory found"
        return
    fi
    
    local count=0
    for env_dir in "$PROJECT_ROOT"/apps/*/; do
        if [ -d "$env_dir" ]; then
            local env_name
            env_name=$(basename "$env_dir")
            for app_file in "$env_dir"*.yaml; do
                if [ -f "$app_file" ]; then
                    local app_name
                    app_name=$(basename "$app_file" .yaml)
                    local full_app_name="$env_name-$app_name"
                    local status="✅"
                    
                    # Check if corresponding manifests exist in environments/
                    local manifest_dir="$PROJECT_ROOT/environments/$env_name/$app_name"
                    
                    if [ ! -d "$manifest_dir" ]; then
                        status="❌ (missing manifests at $manifest_dir)"
                    fi
                    
                    echo "  $status $full_app_name"
                    ((count++))
                fi
            done
        fi
    done
    
    if [ $count -eq 0 ]; then
        log_warning "No applications found"
    else
        echo
        log_info "Total applications: $count"
    fi
}

# Validate configuration
validate_config() {
    log_info "Validating ArgoCD configuration..."
    echo
    
    local errors=0
    
    # Check if application.yaml exists
    if [ ! -f "$PROJECT_ROOT/application.yaml" ]; then
        log_error "application.yaml not found"
        ((errors++))
    else
        log_success "application.yaml found"
    fi
    
    # Check apps directory
    if [ ! -d "$PROJECT_ROOT/apps" ]; then
        log_error "apps directory not found"
        ((errors++))
    else
        log_success "apps directory found"
    fi
    
    # Validate each application
    for env_dir in "$PROJECT_ROOT"/apps/*/; do
        if [ -d "$env_dir" ]; then
            local env_name
            env_name=$(basename "$env_dir")
            for app_file in "$env_dir"*.yaml; do
                if [ -f "$app_file" ]; then
                    local app_name
                    app_name=$(basename "$app_file" .yaml)
                    local full_app_name="$env_name-$app_name"
                    log_info "Validating application: $full_app_name"
                    
                    # Check ArgoCD app definition
                    if [ ! -f "$app_file" ]; then
                        log_error "  Missing apps/$env_name/$app_name.yaml"
                        ((errors++))
                    fi
                    
                    # Check manifest directory
                    local manifest_dir="$PROJECT_ROOT/environments/$env_name/$app_name"
            
                    # Check manifest directory
                    if [ ! -d "$manifest_dir" ]; then
                        log_error "  Missing manifest directory: $manifest_dir/"
                        ((errors++))
                    else
                        # Check required manifests
                        if [ ! -f "$manifest_dir/deployment.yaml" ]; then
                            log_error "  Missing $manifest_dir/deployment.yaml"
                            ((errors++))
                        fi
                        
                        if [ ! -f "$manifest_dir/service.yaml" ]; then
                            log_error "  Missing $manifest_dir/service.yaml"
                            ((errors++))
                        fi
                    fi
                    
                    if [ $errors -eq 0 ]; then
                        log_success "  Application $full_app_name is valid"
                    fi
                fi
            done
        fi
    done
    
    echo
    if [ $errors -eq 0 ]; then
        log_success "All configurations are valid!"
    else
        log_error "Found $errors validation errors"
        return 1
    fi
}

# Force sync application
sync_application() {
    local app_name=$1
    
    log_info "Force syncing application: $app_name"
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        return 1
    fi
    
    # Check if application exists
    if ! kubectl get application "$app_name" -n argocd &> /dev/null; then
        log_error "Application $app_name not found"
        return 1
    fi
    
    # Force sync
    kubectl patch application "$app_name" -n argocd --type merge --patch '{
        "operation": {
            "initiatedBy": {"username": "admin"},
            "sync": {"syncStrategy": {"apply": {"force": true}}}
        }
    }'
    
    log_success "Sync initiated for $app_name"
    log_info "Monitor progress with: $0 monitor"
}

# Port forward to application
port_forward() {
    local app_name=$1
    local local_port=${2:-8080}
    local namespace="$app_name"
    
    log_info "Port forwarding to $app_name application..."
    log_info "Local port: $local_port"
    log_info "Press Ctrl+C to stop"
    echo
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        return 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace not found"
        log_info "Make sure the application is deployed"
        return 1
    fi
    
    # Port forward - determine service name based on app
    local service_name
    if [[ $app_name == *"demo-app"* ]]; then
        service_name="argocd-demo-app-service"
    elif [[ $app_name == *"api-service"* ]]; then
        service_name="api-service"
    else
        service_name="argocd-demo-app-service"  # fallback
    fi
    
    kubectl port-forward "svc/$service_name" -n "$namespace" "$local_port:8080"
}

# Show application logs
show_logs() {
    local app_name=$1
    local namespace="$app_name"
    
    log_info "Showing logs for $app_name application..."
    echo
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        return 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace not found"
        return 1
    fi
    
    # Show logs - determine label selector based on app type
    local label_selector
    if [[ $app_name == *"demo-app"* ]]; then
        label_selector="app=argocd-demo-app"
    elif [[ $app_name == *"api-service"* ]]; then
        label_selector="app=api-service"
    else
        label_selector="app=argocd-demo-app"  # fallback
    fi
    
    kubectl logs -n "$namespace" -l "$label_selector" --tail=100 -f
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command=$1
    shift
    
    case "$command" in
        "install-argocd"|"install")
            "$SCRIPT_DIR/install-argocd.sh" "$@"
            ;;
        "deploy")
            "$SCRIPT_DIR/deploy-applications.sh" "$@"
            ;;
        "add-env"|"add-environment")
            "$SCRIPT_DIR/add-environment.sh" "$@"
            ;;
        "list-apps"|"list-applications"|"list")
            list_applications
            ;;
        "monitor")
            "$SCRIPT_DIR/monitor-environments.sh" "$@"
            ;;
        "cleanup")
            "$SCRIPT_DIR/cleanup-environments.sh" "$@"
            ;;
        "status")
            "$SCRIPT_DIR/monitor-environments.sh" --summary
            ;;
        "sync")
            if [ $# -eq 0 ]; then
                log_error "Application name required for sync command"
                exit 1
            fi
            sync_application "$1"
            ;;
        "logs")
            if [ $# -eq 0 ]; then
                log_error "Application name required for logs command"
                exit 1
            fi
            show_logs "$1"
            ;;
        "port-forward"|"pf")
            if [ $# -eq 0 ]; then
                log_error "Application name required for port-forward command"
                exit 1
            fi
            port_forward "$@"
            ;;
        "validate"|"check")
            validate_config
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
