#!/bin/bash

# cleanup-environments.sh
# Script to clean up ArgoCD per-app applications

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

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS] [app_name]"
    echo
    echo "Clean up ArgoCD per-app applications"
    echo
    echo "Arguments:"
    echo "  app_name           Specific application to clean up (e.g. dev-demo-app, production-api-service)"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -a, --all           Clean up all applications"
    echo "  -f, --force         Skip confirmation prompts"
    echo "  --apps-only         Only clean up ArgoCD applications (keep manifests)"
    echo "  --manifests-only    Only clean up manifest files (keep ArgoCD apps)"
    echo "  --dry-run           Show what would be deleted without actually deleting"
    echo
    echo "Examples:"
    echo "  $0 dev-demo-app          # Clean up dev demo app (with confirmation)"
    echo "  $0 --all --force         # Clean up all applications without confirmation"
    echo "  $0 staging-api-service --apps-only   # Only delete staging api-service ArgoCD application"
    echo "  $0 --all --dry-run       # Show what would be deleted"
}

# Confirm action
confirm_action() {
    local message=$1
    local force=${2:-false}
    
    if [ "$force" = "true" ]; then
        return 0
    fi
    
    echo -e "${YELLOW}$message${NC}"
    read -p "Are you sure? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
}

# Get list of applications
get_applications() {
    local applications=()
    
    # Get applications from .argocd directory
    if [ -d ".argocd" ]; then
        for dir in .argocd/*/; do
            if [ -d "$dir" ]; then
                local app_name
                app_name=$(basename "$dir")
                applications+=("$app_name")
            fi
        done
    fi
    
    printf '%s\n' "${applications[@]}" | sort -u
}

# Clean up ArgoCD application
cleanup_argocd_app() {
    local app_name=$1
    local dry_run=${2:-false}
    
    if [ "$dry_run" = "true" ]; then
        if kubectl get application "$app_name" -n argocd &> /environments/dev/null; then
            echo "[DRY RUN] Would delete ArgoCD application: $app_name"
        fi
        return
    fi
    
    log_info "Cleaning up ArgoCD application: $app_name"
    
    if kubectl get application "$app_name" -n argocd &> /environments/dev/null; then
        # Delete the application (this will also clean up deployed resources)
        kubectl delete application "$app_name" -n argocd
        log_success "Deleted ArgoCD application: $app_name"
        
        # Wait for resources to be cleaned up
        log_info "Waiting for resources to be cleaned up..."
        local namespace="$app_name"
        local timeout=60
        local elapsed=0
        
        while kubectl get namespace "$namespace" &> /environments/dev/null && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
        done
        
        if kubectl get namespace "$namespace" &> /environments/dev/null; then
            log_warning "Namespace $namespace still exists after $timeout seconds"
            log_info "You may need to manually clean it up"
        else
            log_success "Namespace $namespace cleaned up successfully"
        fi
    else
        log_warning "ArgoCD application $app_name not found"
    fi
}

# Clean up manifest files
cleanup_manifests() {
    local app_name=$1
    local dry_run=${2:-false}
    
    # Extract environment and service from app name (e.g., "dev-demo-app" -> "dev" and "demo-app")
    local env_name=${app_name%%-*}
    local service_name=${app_name#*-}
    local manifest_dir="$env_name/$service_name"
    
    if [ "$dry_run" = "true" ]; then
        if [ -d "$manifest_dir" ]; then
            echo "[DRY RUN] Would delete directory: $manifest_dir/"
        fi
        if [ -d ".argocd/$app_name" ]; then
            echo "[DRY RUN] Would delete directory: .argocd/$app_name/"
        fi
        return
    fi
    
    log_info "Cleaning up manifest files for application: $app_name"
    
    # Remove app manifest directory
    if [ -d "$manifest_dir" ]; then
        rm -rf "$manifest_dir"
        log_success "Deleted directory: $manifest_dir/"
        
        # Remove environment directory if it's now empty
        if [ -d "$env_name" ] && [ -z "$(ls -A "$env_name")" ]; then
            rm -rf "$env_name"
            log_success "Deleted empty environment directory: $env_name/"
        fi
    else
        log_warning "Directory $manifest_dir/ not found"
    fi
    
    # Remove .argocd application definition
    if [ -d ".argocd/$app_name" ]; then
        rm -rf ".argocd/$app_name"
        log_success "Deleted directory: .argocd/$app_name/"
    else
        log_warning "Directory .argocd/$app_name/ not found"
    fi
}

# Clean up single application
cleanup_application() {
    local app_name=$1
    local apps_only=${2:-false}
    local manifests_only=${3:-false}
    local dry_run=${4:-false}
    local force=${5:-false}
    
    log_info "Cleaning up application: $app_name"
    
    # Confirm action
    if [ "$dry_run" = "false" ]; then
        confirm_action "This will delete all resources for application '$app_name'" "$force"
    fi
    
    # Clean up ArgoCD application (unless manifests-only)
    if [ "$manifests_only" = "false" ]; then
        cleanup_argocd_app "$app_name" "$dry_run"
    fi
    
    # Clean up manifest files (unless apps-only)
    if [ "$apps_only" = "false" ]; then
        cleanup_manifests "$app_name" "$dry_run"
    fi
    
    if [ "$dry_run" = "false" ]; then
        log_success "Application '$app_name' cleaned up successfully"
    fi
}

# Clean up all applications
cleanup_all_applications() {
    local apps_only=${1:-false}
    local manifests_only=${2:-false}
    local dry_run=${3:-false}
    local force=${4:-false}
    
    log_info "Cleaning up all applications"
    
    local applications
    IFS=$'\n' read -rd '' -a applications <<< "$(get_applications)" || true
    
    if [ ${#applications[@]} -eq 0 ]; then
        log_warning "No applications found to clean up"
        return
    fi
    
    echo "Found applications: ${applications[*]}"
    
    # Confirm action for all applications
    if [ "$dry_run" = "false" ]; then
        confirm_action "This will delete ALL applications and their resources" "$force"
    fi
    
    # Clean up each application
    for app in "${applications[@]}"; do
        echo
        cleanup_application "$app" "$apps_only" "$manifests_only" "$dry_run" true
    done
}

# Main function
main() {
    local app_name=""
    local all_applications=false
    local apps_only=false
    local manifests_only=false
    local dry_run=false
    local force=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--all)
                all_applications=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            --apps-only)
                apps_only=true
                shift
                ;;
            --manifests-only)
                manifests_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$app_name" ]; then
                    app_name=$1
                    shift
                else
                    log_error "Multiple application names specified"
                    show_help
                    exit 1
                fi
                ;;
        esac
    done
    
    # Validate conflicting options
    if [ "$apps_only" = "true" ] && [ "$manifests_only" = "true" ]; then
        log_error "Cannot specify both --apps-only and --manifests-only"
        exit 1
    fi
    
    if [ "$all_applications" = "true" ] && [ -n "$app_name" ]; then
        log_error "Cannot specify both --all and a specific application"
        exit 1
    fi
    
    if [ "$all_applications" = "false" ] && [ -z "$app_name" ]; then
        log_error "Must specify either --all or a specific application name"
        show_help
        exit 1
    fi
    
    # Check prerequisites
    if [ "$apps_only" = "false" ] || [ "$manifests_only" = "true" ]; then
        # No need for kubectl if only cleaning manifest files
        :
    else
        if ! command -v kubectl &> /environments/dev/null; then
            log_error "kubectl is not installed or not in PATH"
            exit 1
        fi
        
        if ! kubectl cluster-info &> /environments/dev/null; then
            log_error "Cannot connect to Kubernetes cluster"
            exit 1
        fi
    fi
    
    echo
    log_info "=========================================="
    log_info "      Per-App Cleanup Script"
    if [ "$dry_run" = "true" ]; then
        log_info "              (DRY RUN MODE)"
    fi
    log_info "=========================================="
    echo
    
    # Execute cleanup
    if [ "$all_applications" = "true" ]; then
        cleanup_all_applications "$apps_only" "$manifests_only" "$dry_run" "$force"
    else
        cleanup_application "$app_name" "$apps_only" "$manifests_only" "$dry_run" "$force"
    fi
    
    if [ "$dry_run" = "false" ]; then
        echo
        log_success "Cleanup completed!"
        
        if [ "$manifests_only" = "false" ]; then
            echo
            log_info "To verify cleanup in the cluster:"
            echo "  kubectl get applications -n argocd"
            echo "  kubectl get namespaces | grep -E '(dev|staging|production)-(demo-app|api-service)'"
        fi
    fi
}

# Run main function
main "$@"
