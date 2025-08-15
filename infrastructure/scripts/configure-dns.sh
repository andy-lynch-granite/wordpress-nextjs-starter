#!/bin/bash
# DNS Configuration Script
# Configures custom domains and SSL certificates for Azure Front Door

set -e

# Configuration
PROJECT_NAME="wordpress-nextjs"
DOMAIN_NAME="${1:-example.com}"
ENVIRONMENT="${2:-prod}"  # prod, staging, dev

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
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Validate inputs
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    error "Environment must be one of: dev, staging, prod"
fi

log "Configuring DNS and SSL for $DOMAIN_NAME ($ENVIRONMENT environment)"

# Check if deployment info exists
DEPLOYMENT_INFO="deployment-info-${ENVIRONMENT}.json"
if [ ! -f "$DEPLOYMENT_INFO" ]; then
    error "Deployment info file not found: $DEPLOYMENT_INFO. Run deployment script first."
fi

# Extract deployment information
RESOURCE_GROUP=$(jq -r '.resourceGroup' "$DEPLOYMENT_INFO")
FRONT_DOOR_PROFILE=$(echo "${PROJECT_NAME}-${ENVIRONMENT}-fd")
FRONT_DOOR_ENDPOINT=$(echo "${PROJECT_NAME}-${ENVIRONMENT}-fd-endpoint")

log "Resource Group: $RESOURCE_GROUP"
log "Front Door Profile: $FRONT_DOOR_PROFILE"
log "Front Door Endpoint: $FRONT_DOOR_ENDPOINT"

# Determine domain based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    CUSTOM_DOMAIN="$DOMAIN_NAME"
    WWW_DOMAIN="www.$DOMAIN_NAME"
else
    CUSTOM_DOMAIN="$ENVIRONMENT.$DOMAIN_NAME"
    WWW_DOMAIN=""
fi

log "Custom Domain: $CUSTOM_DOMAIN"
if [ -n "$WWW_DOMAIN" ]; then
    log "WWW Domain: $WWW_DOMAIN"
fi

# Check DNS propagation
log "Checking DNS propagation for $CUSTOM_DOMAIN..."

FRONT_DOOR_HOSTNAME=$(az cdn afd endpoint show \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$FRONT_DOOR_PROFILE" \
    --endpoint-name "$FRONT_DOOR_ENDPOINT" \
    --query hostName -o tsv)

log "Front Door hostname: $FRONT_DOOR_HOSTNAME"

# Verify DNS record
DNS_TARGET=$(nslookup "$CUSTOM_DOMAIN" | grep -E '^[^;].*CNAME' | awk '{print $NF}' | sed 's/\.$//') || true

if [ "$DNS_TARGET" = "$FRONT_DOOR_HOSTNAME" ]; then
    success "DNS record correctly configured"
else
    warn "DNS record not found or incorrect"
    warn "Expected: $CUSTOM_DOMAIN CNAME $FRONT_DOOR_HOSTNAME"
    warn "Found: $DNS_TARGET"
    
    echo ""
    echo "Please configure the following DNS record with your domain provider:"
    echo "Type: CNAME"
    echo "Name: $(echo $CUSTOM_DOMAIN | sed "s/\.$DOMAIN_NAME$//")"
    echo "Value: $FRONT_DOOR_HOSTNAME"
    echo ""
    
    read -p "Press Enter after configuring DNS record to continue..."
fi

# Add custom domain to Front Door
log "Adding custom domain to Front Door..."

# Create custom domain name (replace dots with dashes)
CUSTOM_DOMAIN_NAME=$(echo "$CUSTOM_DOMAIN" | sed 's/\./-/g')

# Check if custom domain already exists
EXISTING_DOMAIN=$(az cdn afd custom-domain list \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$FRONT_DOOR_PROFILE" \
    --query "[?contains(hostName, '$CUSTOM_DOMAIN')].name" -o tsv || true)

if [ -n "$EXISTING_DOMAIN" ]; then
    log "Custom domain already exists: $EXISTING_DOMAIN"
    CUSTOM_DOMAIN_NAME="$EXISTING_DOMAIN"
else
    log "Creating custom domain: $CUSTOM_DOMAIN_NAME"
    
    az cdn afd custom-domain create \
        --resource-group "$RESOURCE_GROUP" \
        --profile-name "$FRONT_DOOR_PROFILE" \
        --custom-domain-name "$CUSTOM_DOMAIN_NAME" \
        --host-name "$CUSTOM_DOMAIN" \
        --minimum-tls-version TLS12 \
        --certificate-type ManagedCertificate
    
    if [ $? -eq 0 ]; then
        success "Custom domain created successfully"
    else
        error "Failed to create custom domain"
    fi
fi

# Wait for domain validation
log "Waiting for domain validation..."

VALIDATION_TIMEOUT=300  # 5 minutes
VALIDATION_INTERVAL=10  # 10 seconds
ELAPSED=0

while [ $ELAPSED -lt $VALIDATION_TIMEOUT ]; do
    DOMAIN_STATUS=$(az cdn afd custom-domain show \
        --resource-group "$RESOURCE_GROUP" \
        --profile-name "$FRONT_DOOR_PROFILE" \
        --custom-domain-name "$CUSTOM_DOMAIN_NAME" \
        --query domainValidationState -o tsv)
    
    if [ "$DOMAIN_STATUS" = "Approved" ]; then
        success "Domain validation completed"
        break
    elif [ "$DOMAIN_STATUS" = "Rejected" ]; then
        error "Domain validation failed"
    else
        log "Domain validation status: $DOMAIN_STATUS (waiting...)"
        sleep $VALIDATION_INTERVAL
        ELAPSED=$((ELAPSED + VALIDATION_INTERVAL))
    fi
done

if [ $ELAPSED -ge $VALIDATION_TIMEOUT ]; then
    error "Domain validation timed out"
fi

# Associate custom domain with route
log "Associating custom domain with route..."

ROUTE_NAME="static-route"

# Get current route configuration
ROUTE_CONFIG=$(az cdn afd route show \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$FRONT_DOOR_PROFILE" \
    --endpoint-name "$FRONT_DOOR_ENDPOINT" \
    --route-name "$ROUTE_NAME" \
    --query '{customDomains: customDomains, originGroup: originGroup, supportedProtocols: supportedProtocols, patternsToMatch: patternsToMatch, forwardingProtocol: forwardingProtocol, httpsRedirect: httpsRedirect}' -o json)

# Add custom domain to existing domains
CUSTOM_DOMAIN_ID="/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Cdn/profiles/$FRONT_DOOR_PROFILE/customDomains/$CUSTOM_DOMAIN_NAME"

# Update route with custom domain
az cdn afd route update \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$FRONT_DOOR_PROFILE" \
    --endpoint-name "$FRONT_DOOR_ENDPOINT" \
    --route-name "$ROUTE_NAME" \
    --custom-domains "$CUSTOM_DOMAIN_ID" \
    --https-redirect Enabled \
    --forwarding-protocol HttpsOnly

if [ $? -eq 0 ]; then
    success "Route updated with custom domain"
else
    error "Failed to update route"
fi

# Handle WWW domain for production
if [ -n "$WWW_DOMAIN" ]; then
    log "Configuring WWW domain: $WWW_DOMAIN"
    
    # Check WWW DNS
    WWW_DNS_TARGET=$(nslookup "$WWW_DOMAIN" | grep -E '^[^;].*CNAME' | awk '{print $NF}' | sed 's/\.$//') || true
    
    if [ "$WWW_DNS_TARGET" != "$FRONT_DOOR_HOSTNAME" ]; then
        warn "WWW DNS record not configured correctly"
        echo "Please configure: $WWW_DOMAIN CNAME $FRONT_DOOR_HOSTNAME"
    else
        # Create WWW custom domain
        WWW_DOMAIN_NAME=$(echo "$WWW_DOMAIN" | sed 's/\./-/g')
        
        az cdn afd custom-domain create \
            --resource-group "$RESOURCE_GROUP" \
            --profile-name "$FRONT_DOOR_PROFILE" \
            --custom-domain-name "$WWW_DOMAIN_NAME" \
            --host-name "$WWW_DOMAIN" \
            --minimum-tls-version TLS12 \
            --certificate-type ManagedCertificate
        
        success "WWW domain configured"
    fi
fi

# Verify SSL certificate
log "Checking SSL certificate status..."

CERT_STATUS=$(az cdn afd custom-domain show \
    --resource-group "$RESOURCE_GROUP" \
    --profile-name "$FRONT_DOOR_PROFILE" \
    --custom-domain-name "$CUSTOM_DOMAIN_NAME" \
    --query certificateType -o tsv)

if [ "$CERT_STATUS" = "ManagedCertificate" ]; then
    success "SSL certificate configured (managed by Azure)"
else
    warn "SSL certificate status: $CERT_STATUS"
fi

# Test the configuration
log "Testing website accessibility..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$CUSTOM_DOMAIN" || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "404" ]; then
    success "Website is accessible at https://$CUSTOM_DOMAIN"
elif [ "$HTTP_STATUS" = "000" ]; then
    warn "Website not accessible yet (may take time for propagation)"
else
    warn "Website returned HTTP status: $HTTP_STATUS"
fi

# Summary
echo ""
echo "========================================"
echo "       DNS CONFIGURATION COMPLETE"
echo "========================================"
echo "Domain: $CUSTOM_DOMAIN"
echo "Environment: $ENVIRONMENT"
echo "Front Door Profile: $FRONT_DOOR_PROFILE"
echo "SSL Certificate: Managed by Azure"
echo ""
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "404" ]; then
    echo "Status: ✅ Website accessible"
else
    echo "Status: ⏳ Waiting for propagation"
fi
echo ""
echo "Test your website:"
echo "  https://$CUSTOM_DOMAIN"
if [ -n "$WWW_DOMAIN" ]; then
    echo "  https://$WWW_DOMAIN"
fi
echo "========================================"

success "DNS configuration completed successfully!"
