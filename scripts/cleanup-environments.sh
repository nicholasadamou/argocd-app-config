#!/bin/bash

# cleanup-environments.sh
# Script to clean up ArgoCD applications and environments

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
    echo "Usage: $0 [OPTIONS] [environment_name]"
    echo
    echo "Clean up ArgoCD applications and environments"
    echo
    echo "Arguments:"
    echo "  environment_name    Specific environment to clean up (optional)"
    echo
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -a, --all           Clean up all environments"
    echo "  -f, --force         Skip confirmation prompts"
    echo "  --apps-only         Only clean up ArgoCD applications (keep manifests)"
    echo "  --manifests-only    Only clean up manifest files (keep ArgoCD apps)"
    echo "  --dry-run           Show what would be deleted without actually deleting"
    echo
    echo "Examples:"
    echo "  $0 qa                    # Clean up QA environment (with confirmation)"
    echo "  $0 --all --force         # Clean up all environments without confirmation"
    echo "  $0 staging --apps-only   # Only delete staging ArgoCD application"
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

# Get list of environments
get_environments() {
    local environments=()
    
    # Get environments from .argocd directory
    if [ -d ".argocd" ]; then
        for dir in .argocd/*/; do
            if [ -d "$dir" ]; then
                local env_name
                env_name=$(basename "$dir")
                environments+=("$env_name")
            fi
        done
    fi
    
    printf '%s\n' "${environments[@]}" | sort -u
}

# Clean up ArgoCD application
cleanup_argocd_app() {
    local env_name=$1
    local dry_run=${2:-false}
    local app_name="argocd-demo-app-$env_name"
    
    if [ "$dry_run" = "true" ]; then
        if kubectl get application "$app_name" -n argocd &> /dev/null; then
            echo "[DRY RUN] Would delete ArgoCD application: $app_name"
        fi
        return
    fi
    
    log_info "Cleaning up ArgoCD application: $app_name"
    
    if kubectl get application "$app_name" -n argocd &> /dev/null; then
        # Delete the application (this will also clean up deployed resources)
        kubectl delete application "$app_name" -n argocd
        log_success "Deleted ArgoCD application: $app_name"
        
        # Wait for resources to be cleaned up
        log_info "Waiting for resources to be cleaned up..."
        local namespace="argocd-demo-app-$env_name"
        local timeout=60
        local elapsed=0
        
        while kubectl get namespace "$namespace" &> /dev/null && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
        done
        
        if kubectl get namespace "$namespace" &> /dev/null; then
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
    local env_name=$1
    local dry_run=${2:-false}
    
    if [ "$dry_run" = "true" ]; then
        if [ -d "$env_name" ]; then
            echo "[DRY RUN] Would delete directory: $env_name/"
        fi
        if [ -d ".argocd/$env_name" ]; then
            echo "[DRY RUN] Would delete directory: .argocd/$env_name/"
        fi
        return
    fi
    
    log_info "Cleaning up manifest files for environment: $env_name"
    
    # Remove environment directory
    if [ -d "$env_name" ]; then
        rm -rf "$env_name"
        log_success "Deleted directory: $env_name/"
    else
        log_warning "Directory $env_name/ not found"
    fi
    
    # Remove .argocd application definition
    if [ -d ".argocd/$env_name" ]; then
        rm -rf ".argocd/$env_name"
        log_success "Deleted directory: .argocd/$env_name/"
    else
        log_warning "Directory .argocd/$env_name/ not found"
    fi
}

# Clean up single environment
cleanup_environment() {
    local env_name=$1
    local apps_only=${2:-false}
    local manifests_only=${3:-false}
    local dry_run=${4:-false}
    local force=${5:-false}
    
    log_info "Cleaning up environment: $env_name"
    
    # Confirm action
    if [ "$dry_run" = "false" ]; then
        confirm_action "This will delete all resources for environment '$env_name'" "$force"
    fi
    
    # Clean up ArgoCD application (unless manifests-only)
    if [ "$manifests_only" = "false" ]; then
        cleanup_argocd_app "$env_name" "$dry_run"
    fi
    
    # Clean up manifest files (unless apps-only)
    if [ "$apps_only" = "false" ]; then
        cleanup_manifests "$env_name" "$dry_run"
    fi
    
    if [ "$dry_run" = "false" ]; then
        log_success "Environment '$env_name' cleaned up successfully"
    fi
}

# Clean up all environments
cleanup_all_environments() {
    local apps_only=${1:-false}
    local manifests_only=${2:-false}
    local dry_run=${3:-false}
    local force=${4:-false}
    
    log_info "Cleaning up all environments"
    
    local environments
    IFS=$'\n' read -rd '' -a environments <<< "$(get_environments)" || true
    
    if [ ${#environments[@]} -eq 0 ]; then
        log_warning "No environments found to clean up"
        return
    fi
    
    echo "Found environments: ${environments[*]}"
    
    # Confirm action for all environments
    if [ "$dry_run" = "false" ]; then
        confirm_action "This will delete ALL environments and their resources" "$force"
    fi
    
    # Clean up each environment
    for env in "${environments[@]}"; do
        echo
        cleanup_environment "$env" "$apps_only" "$manifests_only" "$dry_run" true
    done
}

# Main function
main() {
    local environment_name=""
    local all_environments=false
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
                all_environments=true
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
    
    # Validate conflicting options
    if [ "$apps_only" = "true" ] && [ "$manifests_only" = "true" ]; then
        log_error "Cannot specify both --apps-only and --manifests-only"
        exit 1
    fi
    
    if [ "$all_environments" = "true" ] && [ -n "$environment_name" ]; then
        log_error "Cannot specify both --all and a specific environment"
        exit 1
    fi
    
    if [ "$all_environments" = "false" ] && [ -z "$environment_name" ]; then
        log_error "Must specify either --all or a specific environment name"
        show_help
        exit 1
    fi
    
    # Check prerequisites
    if [ "$apps_only" = "false" ] || [ "$manifests_only" = "true" ]; then
        # No need for kubectl if only cleaning manifest files
        :
    else
        if ! command -v kubectl &> /dev/null; then
            log_error "kubectl is not installed or not in PATH"
            exit 1
        fi
        
        if ! kubectl cluster-info &> /dev/null; then
            log_error "Cannot connect to Kubernetes cluster"
            exit 1
        fi
    fi
    
    echo
    log_info "=========================================="
    log_info "       Environment Cleanup Script"
    if [ "$dry_run" = "true" ]; then
        log_info "              (DRY RUN MODE)"
    fi
    log_info "=========================================="
    echo
    
    # Execute cleanup
    if [ "$all_environments" = "true" ]; then
        cleanup_all_environments "$apps_only" "$manifests_only" "$dry_run" "$force"
    else
        cleanup_environment "$environment_name" "$apps_only" "$manifests_only" "$dry_run" "$force"
    fi
    
    if [ "$dry_run" = "false" ]; then
        echo
        log_success "Cleanup completed!"
        
        if [ "$manifests_only" = "false" ]; then
            echo
            log_info "To verify cleanup in the cluster:"
            echo "  kubectl get applications -n argocd"
            echo "  kubectl get namespaces | grep argocd-demo-app"
        fi
    fi
}

# Run main function
main "$@"
