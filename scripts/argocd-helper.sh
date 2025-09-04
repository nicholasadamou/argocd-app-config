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
    echo -e "${YELLOW}Environment Management:${NC}"
    echo "  add-env <name>         Add a new environment"
    echo "  list-envs              List all configured environments"
    echo "  monitor                Monitor all environments"
    echo "  cleanup [env]          Clean up environments"
    echo
    echo -e "${YELLOW}Monitoring & Status:${NC}"
    echo "  status                 Show status of all applications"
    echo "  sync <env>             Force sync a specific environment"
    echo "  logs <env>             Show logs for an environment"
    echo
    echo -e "${YELLOW}Utilities:${NC}"
    echo "  port-forward <env>     Port forward to an environment"
    echo "  validate               Validate configuration files"
    echo "  help                   Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 install-argocd"
    echo "  $0 deploy"
    echo "  $0 add-env qa --replicas 3"
    echo "  $0 monitor --watch"
    echo "  $0 status"
    echo "  $0 port-forward dev"
    echo
    echo -e "${CYAN}For detailed help on a specific command:${NC}"
    echo "  $0 <command> --help"
    echo
}

# List environments
list_environments() {
    log_info "Configured environments:"
    echo
    
    if [ ! -d "$PROJECT_ROOT/.argocd" ]; then
        log_warning "No .argocd directory found"
        return
    fi
    
    local count=0
    for dir in "$PROJECT_ROOT"/.argocd/*/; do
        if [ -d "$dir" ]; then
            local env_name
            env_name=$(basename "$dir")
            local manifest_dir="$PROJECT_ROOT/$env_name"
            local status="✅"
            
            if [ ! -d "$manifest_dir" ]; then
                status="❌ (missing manifests)"
            fi
            
            echo "  $status $env_name"
            ((count++))
        fi
    done
    
    if [ $count -eq 0 ]; then
        log_warning "No environments found"
    else
        echo
        log_info "Total environments: $count"
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
    
    # Check .argocd directory
    if [ ! -d "$PROJECT_ROOT/.argocd" ]; then
        log_error ".argocd directory not found"
        ((errors++))
    else
        log_success ".argocd directory found"
    fi
    
    # Validate each environment
    for dir in "$PROJECT_ROOT"/.argocd/*/; do
        if [ -d "$dir" ]; then
            local env_name
            env_name=$(basename "$dir")
            log_info "Validating environment: $env_name"
            
            # Check ArgoCD app definition
            if [ ! -f "$dir/app.yaml" ]; then
                log_error "  Missing .argocd/$env_name/app.yaml"
                ((errors++))
            fi
            
            # Check manifest directory
            if [ ! -d "$PROJECT_ROOT/$env_name" ]; then
                log_error "  Missing manifest directory: $env_name/"
                ((errors++))
            else
                # Check required manifests
                if [ ! -f "$PROJECT_ROOT/$env_name/deployment.yaml" ]; then
                    log_error "  Missing $env_name/deployment.yaml"
                    ((errors++))
                fi
                
                if [ ! -f "$PROJECT_ROOT/$env_name/service.yaml" ]; then
                    log_error "  Missing $env_name/service.yaml"
                    ((errors++))
                fi
            fi
            
            if [ $errors -eq 0 ]; then
                log_success "  Environment $env_name is valid"
            fi
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

# Force sync environment
sync_environment() {
    local env_name=$1
    local app_name="argocd-demo-app-$env_name"
    
    log_info "Force syncing environment: $env_name"
    
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
    
    log_success "Sync initiated for $env_name"
    log_info "Monitor progress with: $0 monitor"
}

# Port forward to environment
port_forward() {
    local env_name=$1
    local local_port=${2:-8080}
    local namespace="argocd-demo-app-$env_name"
    
    log_info "Port forwarding to $env_name environment..."
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
        log_info "Make sure the environment is deployed"
        return 1
    fi
    
    # Port forward
    kubectl port-forward svc/argocd-demo-app-service -n "$namespace" "$local_port:8080"
}

# Show environment logs
show_logs() {
    local env_name=$1
    local namespace="argocd-demo-app-$env_name"
    
    log_info "Showing logs for $env_name environment..."
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
    
    # Show logs
    kubectl logs -n "$namespace" -l app=argocd-demo-app --tail=100 -f
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
        "list-envs"|"list-environments"|"list")
            list_environments
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
                log_error "Environment name required for sync command"
                exit 1
            fi
            sync_environment "$1"
            ;;
        "logs")
            if [ $# -eq 0 ]; then
                log_error "Environment name required for logs command"
                exit 1
            fi
            show_logs "$1"
            ;;
        "port-forward"|"pf")
            if [ $# -eq 0 ]; then
                log_error "Environment name required for port-forward command"
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
