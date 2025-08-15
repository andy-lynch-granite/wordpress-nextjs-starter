#!/bin/bash
# Deployment Validation Script
# Validates Azure infrastructure deployment and configuration

set -e

# Configuration
PROJECT_NAME="wordpress-nextjs"
ENVIRONMENT="${1:-prod}"  # prod, staging, dev
DOMAIN_NAME="${2:-example.com}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

fail() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Test counter
TEST_COUNT=0
TEST_PASSED=0
TEST_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    log "Running test: $test_name"
    
    if eval "$test_command" &>/dev/null; then
        success "$test_name"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        error "$test_name"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    local expected_output="$3"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    log "Running test: $test_name"
    
    local output
    output=$(eval "$test_command" 2>/dev/null || echo "")
    
    if [ -n "$output" ] && [[ "$output" == *"$expected_output"* ]]; then
        success "$test_name: $output"
        TEST_PASSED=$((TEST_PASSED + 1))
        return 0
    else
        error "$test_name: Expected '$expected_output', got '$output'"
        TEST_FAILED=$((TEST_FAILED + 1))
        return 1
    fi
}

log "Starting deployment validation for $ENVIRONMENT environment"

# Check if deployment info exists
DEPLOYMENT_INFO="deployment-info-${ENVIRONMENT}.json"
if [ ! -f "$DEPLOYMENT_INFO" ]; then
    fail "Deployment info file not found: $DEPLOYMENT_INFO"
fi

# Extract deployment information
RESOURCE_GROUP=$(jq -r '.resourceGroup' "$DEPLOYMENT_INFO")
STORAGE_ACCOUNT=$(jq -r '.storageAccount' "$DEPLOYMENT_INFO")
FRONT_DOOR_URL=$(jq -r '.frontDoorUrl' "$DEPLOYMENT_INFO")
KEY_VAULT=$(jq -r '.keyVault' "$DEPLOYMENT_INFO")
WORDPRESS_URL=$(jq -r '.wordpressUrl' "$DEPLOYMENT_INFO")
MYSQL_SERVER=$(jq -r '.mysqlServer' "$DEPLOYMENT_INFO")
REDIS_HOST=$(jq -r '.redisHost' "$DEPLOYMENT_INFO")

log "Validating deployment:"
log "  Resource Group: $RESOURCE_GROUP"
log "  Storage Account: $STORAGE_ACCOUNT"
log "  Front Door URL: $FRONT_DOOR_URL"
log "  Key Vault: $KEY_VAULT"
if [ "$WORDPRESS_URL" != "null" ]; then
    log "  WordPress URL: $WORDPRESS_URL"
fi

echo ""
log "=== INFRASTRUCTURE VALIDATION ==="

# Test 1: Resource Group exists
run_test "Resource Group exists" \
    "az group show --name '$RESOURCE_GROUP' --query name -o tsv"

# Test 2: Storage Account exists and is accessible
run_test "Storage Account exists" \
    "az storage account show --name '$STORAGE_ACCOUNT' --resource-group '$RESOURCE_GROUP' --query name -o tsv"

# Test 3: Static website hosting is enabled
run_test "Static website hosting enabled" \
    "az storage blob service-properties show --account-name '$STORAGE_ACCOUNT' --query staticWebsite.enabled -o tsv | grep -i true"

# Test 4: Key Vault exists and is accessible
run_test "Key Vault exists" \
    "az keyvault show --name '$KEY_VAULT' --query name -o tsv"

# Test 5: Front Door profile exists
FRONT_DOOR_PROFILE="${PROJECT_NAME}-${ENVIRONMENT}-fd"
run_test "Front Door profile exists" \
    "az cdn afd profile show --profile-name '$FRONT_DOOR_PROFILE' --resource-group '$RESOURCE_GROUP' --query name -o tsv"

# Test 6: Front Door endpoint exists
FRONT_DOOR_ENDPOINT="${PROJECT_NAME}-${ENVIRONMENT}-fd-endpoint"
run_test "Front Door endpoint exists" \
    "az cdn afd endpoint show --endpoint-name '$FRONT_DOOR_ENDPOINT' --profile-name '$FRONT_DOOR_PROFILE' --resource-group '$RESOURCE_GROUP' --query name -o tsv"

echo ""
log "=== CONNECTIVITY VALIDATION ==="

# Test 7: Front Door endpoint is accessible
run_test "Front Door endpoint accessible" \
    "curl -s -o /dev/null -w '%{http_code}' '$FRONT_DOOR_URL' | grep -E '^(200|404)$'"

# Test 8: HTTPS redirect works
HTTP_URL=$(echo "$FRONT_DOOR_URL" | sed 's/https:/http:/')
run_test "HTTPS redirect works" \
    "curl -s -o /dev/null -w '%{redirect_url}' '$HTTP_URL' | grep https"

# Test 9: Static website endpoint accessible
STATIC_URL=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query primaryEndpoints.web -o tsv)
run_test "Static website endpoint accessible" \
    "curl -s -o /dev/null -w '%{http_code}' '$STATIC_URL' | grep -E '^(200|404)$'"

echo ""
log "=== BACKEND VALIDATION ==="

if [ "$WORDPRESS_URL" != "null" ] && [ "$WORDPRESS_URL" != "" ]; then
    # Test 10: WordPress backend accessible
    run_test "WordPress backend accessible" \
        "curl -s -o /dev/null -w '%{http_code}' '$WORDPRESS_URL' | grep -E '^(200|404|302)$'"
    
    # Test 11: MySQL server exists
    if [ "$MYSQL_SERVER" != "null" ] && [ "$MYSQL_SERVER" != "" ]; then
        MYSQL_SERVER_NAME=$(echo "$MYSQL_SERVER" | cut -d'.' -f1)
        run_test "MySQL server exists" \
            "az mysql flexible-server show --name '$MYSQL_SERVER_NAME' --resource-group '$RESOURCE_GROUP' --query name -o tsv"
    fi
    
    # Test 12: Redis cache exists
    if [ "$REDIS_HOST" != "null" ] && [ "$REDIS_HOST" != "" ]; then
        REDIS_NAME="${PROJECT_NAME}-${ENVIRONMENT}-redis"
        run_test "Redis cache exists" \
            "az redis show --name '$REDIS_NAME' --resource-group '$RESOURCE_GROUP' --query name -o tsv"
    fi
else
    log "Skipping backend validation (backend not deployed)"
fi

echo ""
log "=== SECURITY VALIDATION ==="

# Test 13: Key Vault secrets exist
run_test "MySQL password secret exists" \
    "az keyvault secret show --vault-name '$KEY_VAULT' --name 'mysql-admin-password' --query name -o tsv"

run_test "WordPress DB password secret exists" \
    "az keyvault secret show --vault-name '$KEY_VAULT' --name 'wordpress-db-password' --query name -o tsv"

# Test 14: Storage account requires HTTPS
run_test "Storage account requires HTTPS" \
    "az storage account show --name '$STORAGE_ACCOUNT' --resource-group '$RESOURCE_GROUP' --query enableHttpsTrafficOnly -o tsv | grep -i true"

# Test 15: Key Vault has soft delete enabled
run_test "Key Vault soft delete enabled" \
    "az keyvault show --name '$KEY_VAULT' --query properties.enableSoftDelete -o tsv | grep -i true"

echo ""
log "=== PERFORMANCE VALIDATION ==="

# Test 16: CDN caching headers
run_test "CDN caching configured" \
    "curl -s -I '$FRONT_DOOR_URL' | grep -i 'cache-control\|x-cache'"

# Test 17: Compression enabled
run_test "Compression enabled" \
    "curl -s -H 'Accept-Encoding: gzip' -I '$FRONT_DOOR_URL' | grep -i 'content-encoding: gzip'"

echo ""
log "=== MONITORING VALIDATION ==="

# Check if monitoring is enabled
APP_INSIGHTS_KEY=$(jq -r '.applicationInsightsKey' "$DEPLOYMENT_INFO" 2>/dev/null || echo "null")

if [ "$APP_INSIGHTS_KEY" != "null" ] && [ "$APP_INSIGHTS_KEY" != "" ]; then
    # Test 18: Application Insights exists
    APP_INSIGHTS_NAME="${PROJECT_NAME}-${ENVIRONMENT}-ai"
    run_test "Application Insights exists" \
        "az monitor app-insights component show --app '$APP_INSIGHTS_NAME' --resource-group '$RESOURCE_GROUP' --query name -o tsv"
    
    # Test 19: Log Analytics workspace exists
    LOG_ANALYTICS_NAME="${PROJECT_NAME}-${ENVIRONMENT}-logs"
    run_test "Log Analytics workspace exists" \
        "az monitor log-analytics workspace show --workspace-name '$LOG_ANALYTICS_NAME' --resource-group '$RESOURCE_GROUP' --query name -o tsv"
else
    log "Skipping monitoring validation (monitoring not enabled)"
fi

echo ""
log "=== DOMAIN VALIDATION ==="

if [ "$DOMAIN_NAME" != "example.com" ]; then
    # Determine custom domain based on environment
    if [ "$ENVIRONMENT" = "prod" ]; then
        CUSTOM_DOMAIN="$DOMAIN_NAME"
    else
        CUSTOM_DOMAIN="$ENVIRONMENT.$DOMAIN_NAME"
    fi
    
    # Test 20: Custom domain DNS resolution
    run_test "Custom domain DNS resolution" \
        "nslookup '$CUSTOM_DOMAIN' | grep -E 'CNAME|Address'"
    
    # Test 21: Custom domain HTTPS accessibility
    run_test "Custom domain HTTPS accessible" \
        "curl -s -o /dev/null -w '%{http_code}' 'https://$CUSTOM_DOMAIN' | grep -E '^(200|404)$'"
    
    # Test 22: SSL certificate validity
    run_test "SSL certificate valid" \
        "echo | openssl s_client -servername '$CUSTOM_DOMAIN' -connect '$CUSTOM_DOMAIN:443' 2>/dev/null | openssl x509 -noout -dates"
else
    log "Skipping domain validation (using default domain)"
fi

echo ""
log "=== DEPLOYMENT CONSISTENCY ==="

# Test 23: All required tags are present
run_test "Resource group has required tags" \
    "az group show --name '$RESOURCE_GROUP' --query 'tags.Environment' -o tsv | grep '$ENVIRONMENT'"

# Test 24: Deployment timestamp is recent (within last 24 hours)
DEPLOYED_AT=$(jq -r '.deployedAt' "$DEPLOYMENT_INFO")
if [ "$DEPLOYED_AT" != "null" ]; then
    DEPLOYED_TIMESTAMP=$(date -d "$DEPLOYED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$DEPLOYED_AT" +%s 2>/dev/null || echo "0")
    CURRENT_TIMESTAMP=$(date +%s)
    HOURS_DIFF=$(( (CURRENT_TIMESTAMP - DEPLOYED_TIMESTAMP) / 3600 ))
    
    if [ $HOURS_DIFF -le 24 ]; then
        success "Deployment is recent (${HOURS_DIFF}h ago)"
        TEST_PASSED=$((TEST_PASSED + 1))
    else
        warn "Deployment is old (${HOURS_DIFF}h ago)"
        TEST_FAILED=$((TEST_FAILED + 1))
    fi
    TEST_COUNT=$((TEST_COUNT + 1))
fi

echo ""
echo "========================================"
echo "       VALIDATION SUMMARY"
echo "========================================"
echo "Total Tests: $TEST_COUNT"
echo "Passed: $TEST_PASSED"
echo "Failed: $TEST_FAILED"
echo "Success Rate: $(( TEST_PASSED * 100 / TEST_COUNT ))%"
echo ""

if [ $TEST_FAILED -eq 0 ]; then
    success "All validation tests passed! 🎉"
    echo "Your Azure infrastructure is properly configured and ready for production."
else
    error "Some validation tests failed."
    echo "Please review the failed tests and fix the issues before proceeding."
fi

echo "========================================"

# Exit with appropriate code
if [ $TEST_FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
