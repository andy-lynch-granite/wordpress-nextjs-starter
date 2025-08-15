#!/bin/bash
# Environment Setup Script
# Sets up production and preview environments with proper configuration

set -e

# Configuration
PROJECT_NAME="wordpress-nextjs"
DOMAIN_NAME="${1:-example.com}"
GITHUB_REPO="${2:-your-org/wordpress-nextjs-starter}"

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

log "Setting up environments for $PROJECT_NAME"
log "Domain: $DOMAIN_NAME"
log "GitHub Repository: $GITHUB_REPO"

# Check if deployment info files exist
PROD_INFO="deployment-info-prod.json"
STAGING_INFO="deployment-info-staging.json"
DEV_INFO="deployment-info-dev.json"

if [ ! -f "$PROD_INFO" ]; then
    warn "Production deployment info not found. Run deployment script first."
fi

if [ ! -f "$STAGING_INFO" ]; then
    warn "Staging deployment info not found. Run deployment script first."
fi

# Create service principal for GitHub Actions
log "Creating service principal for GitHub Actions..."

# Get subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

log "Using subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"

# Create service principal
SP_NAME="${PROJECT_NAME}-github-actions"
SP_OUTPUT=$(az ad sp create-for-rbac \
    --name "$SP_NAME" \
    --role contributor \
    --scopes "/subscriptions/$SUBSCRIPTION_ID" \
    --sdk-auth)

if [ $? -eq 0 ]; then
    success "Service principal created successfully"
    
    # Save service principal credentials
    echo "$SP_OUTPUT" > "service-principal-credentials.json"
    
    log "Service principal credentials saved to: service-principal-credentials.json"
    warn "Keep these credentials secure and add them to GitHub Secrets as AZURE_CREDENTIALS"
else
    error "Failed to create service principal"
fi

# Configure static website hosting
log "Configuring static website hosting..."

for env in "prod" "staging" "dev"; do
    info_file="deployment-info-${env}.json"
    
    if [ -f "$info_file" ]; then
        log "Configuring $env environment..."
        
        # Extract values from deployment info
        storage_account=$(jq -r '.storageAccount' "$info_file")
        resource_group=$(jq -r '.resourceGroup' "$info_file")
        
        if [ "$storage_account" != "null" ] && [ "$resource_group" != "null" ]; then
            # Enable static website hosting
            az storage blob service-properties update \
                --account-name "$storage_account" \
                --static-website \
                --404-document "404.html" \
                --index-document "index.html" \
                --output none
            
            # Set CORS rules
            az storage cors add \
                --account-name "$storage_account" \
                --services b \
                --methods GET HEAD OPTIONS \
                --origins "https://$DOMAIN_NAME" "https://*.$DOMAIN_NAME" \
                --allowed-headers "*" \
                --exposed-headers "*" \
                --max-age 86400 \
                --output none
            
            success "$env environment configured successfully"
        else
            warn "Skipping $env environment - missing deployment info"
        fi
    else
        warn "Skipping $env environment - deployment info file not found"
    fi
done

# Create GitHub environment configurations
log "Creating GitHub environment configurations..."

mkdir -p github-environments

# Production environment
cat > "github-environments/production.json" << EOF
{
  "name": "production",
  "protection_rules": [
    {
      "type": "required_reviewers",
      "required_reviewers": {
        "users": [],
        "teams": []
      }
    },
    {
      "type": "wait_timer",
      "wait_timer": {
        "minutes": 0
      }
    }
  ],
  "deployment_branch_policy": {
    "protected_branches": true,
    "custom_branch_policies": false
  }
}
EOF

# Staging environment
cat > "github-environments/staging.json" << EOF
{
  "name": "staging",
  "protection_rules": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true,
    "custom_branches": ["main", "develop"]
  }
}
EOF

# Development environment
cat > "github-environments/development.json" << EOF
{
  "name": "development",
  "protection_rules": [],
  "deployment_branch_policy": {
    "protected_branches": false,
    "custom_branch_policies": true,
    "custom_branches": ["*"]
  }
}
EOF

success "GitHub environment configurations created"

# Create environment variables file
log "Creating environment variables file..."

cat > "environment-variables.env" << EOF
# Azure Configuration
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
PROJECT_NAME=$PROJECT_NAME
DOMAIN_NAME=$DOMAIN_NAME
GITHUB_REPO=$GITHUB_REPO

# Production Environment
EOF

if [ -f "$PROD_INFO" ]; then
    cat >> "environment-variables.env" << EOF
PROD_RESOURCE_GROUP=$(jq -r '.resourceGroup' "$PROD_INFO")
PROD_STORAGE_ACCOUNT=$(jq -r '.storageAccount' "$PROD_INFO")
PROD_FRONT_DOOR_URL=$(jq -r '.frontDoorUrl' "$PROD_INFO")
PROD_KEY_VAULT=$(jq -r '.keyVault' "$PROD_INFO")
PROD_WORDPRESS_URL=$(jq -r '.wordpressUrl' "$PROD_INFO")

EOF
fi

if [ -f "$STAGING_INFO" ]; then
    cat >> "environment-variables.env" << EOF
# Staging Environment
STAGING_RESOURCE_GROUP=$(jq -r '.resourceGroup' "$STAGING_INFO")
STAGING_STORAGE_ACCOUNT=$(jq -r '.storageAccount' "$STAGING_INFO")
STAGING_FRONT_DOOR_URL=$(jq -r '.frontDoorUrl' "$STAGING_INFO")
STAGING_KEY_VAULT=$(jq -r '.keyVault' "$STAGING_INFO")
STAGING_WORDPRESS_URL=$(jq -r '.wordpressUrl' "$STAGING_INFO")

EOF
fi

if [ -f "$DEV_INFO" ]; then
    cat >> "environment-variables.env" << EOF
# Development Environment
DEV_RESOURCE_GROUP=$(jq -r '.resourceGroup' "$DEV_INFO")
DEV_STORAGE_ACCOUNT=$(jq -r '.storageAccount' "$DEV_INFO")
DEV_FRONT_DOOR_URL=$(jq -r '.frontDoorUrl' "$DEV_INFO")
DEV_KEY_VAULT=$(jq -r '.keyVault' "$DEV_INFO")
DEV_WORDPRESS_URL=$(jq -r '.wordpressUrl' "$DEV_INFO")

EOF
fi

success "Environment variables file created: environment-variables.env"

# Create DNS configuration guide
log "Creating DNS configuration guide..."

cat > "dns-configuration.md" << EOF
# DNS Configuration Guide

## Required DNS Records

Configure the following DNS records with your domain provider:

### Production Environment
\`\`\`
# Primary domain
$DOMAIN_NAME        CNAME   $(jq -r '.frontDoorUrl' "$PROD_INFO" 2>/dev/null | sed 's|https://||' || echo 'FRONT_DOOR_ENDPOINT')

# WWW redirect
www.$DOMAIN_NAME    CNAME   $(jq -r '.frontDoorUrl' "$PROD_INFO" 2>/dev/null | sed 's|https://||' || echo 'FRONT_DOOR_ENDPOINT')
\`\`\`

### Staging Environment
\`\`\`
# Staging subdomain
staging.$DOMAIN_NAME    CNAME   $(jq -r '.frontDoorUrl' "$STAGING_INFO" 2>/dev/null | sed 's|https://||' || echo 'STAGING_FRONT_DOOR_ENDPOINT')
\`\`\`

### Development Environment
\`\`\`
# Development subdomain
dev.$DOMAIN_NAME        CNAME   $(jq -r '.frontDoorUrl' "$DEV_INFO" 2>/dev/null | sed 's|https://||' || echo 'DEV_FRONT_DOOR_ENDPOINT')
\`\`\`

## SSL Certificate Configuration

SSL certificates will be automatically managed by Azure Front Door once DNS records are configured.

## Verification

After configuring DNS records, verify the setup:

1. Wait for DNS propagation (up to 48 hours)
2. Check SSL certificate status in Azure Portal
3. Test website accessibility
4. Verify CDN functionality

EOF

success "DNS configuration guide created: dns-configuration.md"

# Summary
echo ""
echo "========================================"
echo "       ENVIRONMENT SETUP COMPLETE"
echo "========================================"
echo "Files created:"
echo "  - service-principal-credentials.json"
echo "  - github-environments/production.json"
echo "  - github-environments/staging.json"
echo "  - github-environments/development.json"
echo "  - environment-variables.env"
echo "  - dns-configuration.md"
echo ""
echo "Next steps:"
echo "1. Add AZURE_CREDENTIALS to GitHub Secrets"
echo "2. Configure DNS records as described in dns-configuration.md"
echo "3. Set up GitHub environments using the JSON configurations"
echo "4. Run GitHub Actions workflows to deploy applications"
echo "========================================"

success "Environment setup completed successfully!"
