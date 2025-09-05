#!/bin/bash

# Test script to demonstrate per-app selective post-sync hooks
# This script shows exactly which hooks run for different change scenarios

set -e

echo "🚀 Per-App Selective Post-Sync Hook Demo"
echo "========================================"

function test_app_change() {
    local app_path=$1
    local description=$2
    
    echo ""
    echo "📝 Scenario: $description"
    echo "   File changed: $app_path"
    echo ""
    
    # Extract environment and app from path
    local env=$(echo "$app_path" | cut -d'/' -f1)
    local app=$(echo "$app_path" | cut -d'/' -f2)
    local app_name="${env}-${app}"
    
    # Show which ArgoCD application will sync
    echo "   ArgoCD Application that will sync:"
    echo "   ✅ $app_name"
    
    # Show which hook will run
    echo "   Post-sync hook that will execute:"
    case $app_name in
        "dev-demo-app")
            echo "   ✅ dev-demo-app-post-sync (namespace: dev-demo-app)"
            echo "      - Basic health check on argocd-demo-app-service:8080"
            ;;
        "dev-api-service")
            echo "   ✅ dev-api-service-post-sync (namespace: dev-api-service)"
            echo "      - Health check on api-service"
            ;;
        "staging-demo-app")
            echo "   ✅ staging-demo-app-post-sync (namespace: staging-demo-app)"
            echo "      - Enhanced health check with longer wait time"
            ;;
        "staging-api-service")
            echo "   ✅ staging-api-service-post-sync (namespace: staging-api-service)"
            echo "      - API service validation"
            ;;
        "production-demo-app")
            echo "   ✅ production-demo-app-validation (namespace: production-demo-app)"
            echo "      - Comprehensive health check + content validation"
            echo "      - 5 retry attempts, 30s startup wait"
            ;;
        "production-api-service")
            echo "   ✅ production-api-service-validation (namespace: production-api-service)"
            echo "      - Health check + load balancer validation (3 replicas)"
            echo "      - 5 retry attempts, 30s startup wait"
            ;;
    esac
    
    echo "   Other applications: No sync, no hooks triggered ❌"
}

echo ""
echo "🎯 Single App Update Scenarios:"
echo "================================"

test_app_change "environments/dev/demo-app/deployment.yaml" "Update Dev Demo App only"
test_app_change "environments/dev/api-service/service.yaml" "Update Dev API Service only" 
test_app_change "environments/production/demo-app/deployment.yaml" "Update Production Demo App only"
test_app_change "environments/production/api-service/deployment.yaml" "Update Production API Service only"

echo ""
echo "🔀 Multi-App Scenarios:"
echo "======================"

echo ""
echo "📝 Scenario: Update same app across environments"
echo "   Files: environments/staging/demo-app/*, environments/production/demo-app/*"
echo "   Applications that will sync:"
echo "   ✅ staging-demo-app"
echo "   ✅ production-demo-app"
echo "   Hooks that will run:"
echo "   ✅ staging-demo-app-post-sync"
echo "   ✅ production-demo-app-validation"
echo "   Other apps: dev-demo-app, *-api-service remain untouched ❌"

echo ""
echo "📝 Scenario: Update all apps in one environment"
echo "   Files: environments/dev/demo-app/*, environments/dev/api-service/*"
echo "   Applications that will sync:"
echo "   ✅ dev-demo-app"
echo "   ✅ dev-api-service"
echo "   Hooks that will run:"
echo "   ✅ dev-demo-app-post-sync"
echo "   ✅ dev-api-service-post-sync"
echo "   Other environments: environments/staging/*, environments/production/* remain untouched ❌"

echo ""
echo "✨ Key Benefits of Per-App Hooks:"
echo "   1. 🎯 Surgical precision - only affected app runs validation"
echo "   2. ⚡ Lightning fast - no waiting for unrelated app tests"
echo "   3. 🔧 Custom validation - each app can have different test logic"
echo "   4. 🔍 Clear debugging - failures are app-specific, not environment-wide"
echo "   5. 💰 Cost efficient - minimal resource usage for validation"
echo "   6. 🚀 Parallel execution - multiple apps can validate simultaneously"

echo ""
echo "🔍 Monitor Per-App Hook Execution:"
echo "   # Check jobs in specific app namespaces"
echo "   kubectl get jobs -n dev-demo-app"
echo "   kubectl get jobs -n dev-api-service" 
echo "   kubectl get jobs -n production-demo-app"
echo "   kubectl get jobs -n production-api-service"
echo ""
echo "   # Check hook logs for specific app"
echo "   kubectl logs -n dev-demo-app job/dev-demo-app-post-sync"
echo "   kubectl logs -n production-api-service job/production-api-service-validation"

echo ""
echo "🎉 Perfect! Your setup now supports per-app post-sync hooks!"
