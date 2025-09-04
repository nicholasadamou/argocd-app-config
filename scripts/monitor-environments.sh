#!/bin/bash

# monitor-environments.sh  
# Script to monitor all ArgoCD environments and their sync status

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Get sync status with color coding
get_sync_status() {
    local app=$1
    local status
    status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    
    case "$status" in
        "Synced")
            echo -e "${GREEN}$status${NC}"
            ;;
        "OutOfSync")
            echo -e "${YELLOW}$status${NC}"
            ;;
        "Unknown")
            echo -e "${RED}$status${NC}"
            ;;
        *)
            echo -e "${CYAN}$status${NC}"
            ;;
    esac
}

# Get health status with color coding
get_health_status() {
    local app=$1
    local status
    status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    case "$status" in
        "Healthy")
            echo -e "${GREEN}$status${NC}"
            ;;
        "Progressing")
            echo -e "${YELLOW}$status${NC}"
            ;;
        "Degraded"|"Missing")
            echo -e "${RED}$status${NC}"
            ;;
        "Suspended")
            echo -e "${PURPLE}$status${NC}"
            ;;
        *)
            echo -e "${CYAN}$status${NC}"
            ;;
    esac
}

# Get last sync time
get_last_sync() {
    local app=$1
    local sync_time
    sync_time=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.operationState.finishedAt}' 2>/dev/null || echo "")
    
    if [ -n "$sync_time" ]; then
        # Convert to local time and format
        date -d "$sync_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$sync_time"
    else
        echo "Never"
    fi
}

# Get resource count for namespace
get_resource_count() {
    local namespace=$1
    if kubectl get namespace "$namespace" &> /dev/null; then
        kubectl get all -n "$namespace" --no-headers 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

# Show detailed application info
show_application_details() {
    local app=$1
    local environment=${app##*-}  # Extract environment from app name
    local namespace="argocd-demo-app-$environment"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}🚀 Environment: ${YELLOW}$environment${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if kubectl get application "$app" -n argocd &> /dev/null; then
        local sync_status health_status last_sync resource_count
        sync_status=$(get_sync_status "$app")
        health_status=$(get_health_status "$app")
        last_sync=$(get_last_sync "$app")
        resource_count=$(get_resource_count "$namespace")
        
        printf "%-15s %s\n" "Application:" "$app"
        printf "%-15s %s\n" "Namespace:" "$namespace"
        printf "%-15s %s\n" "Sync Status:" "$sync_status"
        printf "%-15s %s\n" "Health Status:" "$health_status"
        printf "%-15s %s\n" "Last Sync:" "$last_sync"
        printf "%-15s %s\n" "Resources:" "$resource_count"
        
        # Show recent events if available
        local events
        events=$(kubectl get events -n argocd --field-selector involvedObject.name="$app" --sort-by='.lastTimestamp' -o custom-columns="TIME:.lastTimestamp,REASON:.reason,MESSAGE:.message" --no-headers 2>/dev/null | tail -3)
        if [ -n "$events" ]; then
            echo
            echo -e "${BLUE}Recent Events:${NC}"
            echo "$events" | while read -r line; do
                echo "  $line"
            done
        fi
        
        # Show pod status if namespace exists
        if kubectl get namespace "$namespace" &> /dev/null; then
            echo
            echo -e "${BLUE}Pod Status:${NC}"
            kubectl get pods -n "$namespace" -o wide 2>/dev/null || echo "  No pods found"
        fi
        
    else
        echo -e "${RED}❌ Application not found${NC}"
    fi
    
    echo
}

# Show summary table
show_summary_table() {
    log_info "Environment Summary"
    echo
    printf "%-12s %-15s %-15s %-20s %-10s\n" "Environment" "Sync Status" "Health Status" "Last Sync" "Resources"
    printf "%-12s %-15s %-15s %-20s %-10s\n" "━━━━━━━━━━━" "━━━━━━━━━━━━━━" "━━━━━━━━━━━━━━" "━━━━━━━━━━━━━━━━━━━━" "━━━━━━━━━"
    
    local apps=("argocd-demo-app-dev" "argocd-demo-app-staging" "argocd-demo-app-production")
    
    for app in "${apps[@]}"; do
        local environment=${app##*-}
        local namespace="argocd-demo-app-$environment"
        
        if kubectl get application "$app" -n argocd &> /dev/null; then
            local sync_status health_status last_sync resource_count
            sync_status=$(get_sync_status "$app")
            health_status=$(get_health_status "$app")
            last_sync=$(get_last_sync "$app")
            resource_count=$(get_resource_count "$namespace")
            
            printf "%-12s %-25s %-25s %-20s %-10s\n" "$environment" "$sync_status" "$health_status" "$last_sync" "$resource_count"
        else
            printf "%-12s %-15s %-15s %-20s %-10s\n" "$environment" "Not Found" "-" "-" "-"
        fi
    done
    echo
}

# Watch mode function
watch_mode() {
    log_info "Starting watch mode (press Ctrl+C to exit)..."
    echo
    
    while true; do
        clear
        echo -e "${PURPLE}ArgoCD Environment Monitor - $(date)${NC}"
        echo
        show_summary_table
        sleep 5
    done
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Monitor ArgoCD applications across all environments"
    echo
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -w, --watch     Watch mode (continuous monitoring)"
    echo "  -d, --details   Show detailed information for each environment"
    echo "  -s, --summary   Show summary table only (default)"
    echo
    echo "Examples:"
    echo "  $0                  # Show summary table"
    echo "  $0 --details        # Show detailed information"
    echo "  $0 --watch          # Continuous monitoring"
}

# Main function
main() {
    local show_details=false
    local watch_mode_enabled=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -w|--watch)
                watch_mode_enabled=true
                shift
                ;;
            -d|--details)
                show_details=true
                shift
                ;;
            -s|--summary)
                show_details=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Run appropriate mode
    if [ "$watch_mode_enabled" = true ]; then
        watch_mode
    elif [ "$show_details" = true ]; then
        echo -e "${PURPLE}ArgoCD Environment Monitor - Detailed View${NC}"
        echo
        
        local apps=("argocd-demo-app-dev" "argocd-demo-app-staging" "argocd-demo-app-production")
        for app in "${apps[@]}"; do
            show_application_details "$app"
        done
    else
        echo -e "${PURPLE}ArgoCD Environment Monitor${NC}"
        echo
        show_summary_table
        
        log_info "Use --details for detailed information or --watch for continuous monitoring"
    fi
}

# Run main function
main "$@"
