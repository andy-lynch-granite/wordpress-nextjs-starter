#!/bin/bash

# Create Confluence Space and Pages Script
# This script creates the HWPSK space and basic page structure in Confluence

set -e

# Configuration
CONFLUENCE_URL="https://andylynchgranite.atlassian.net"
CONFLUENCE_SPACE="HWPSK"
ATLASSIAN_EMAIL="andrew.lynch@granite.ie"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if API token is available
check_credentials() {
    if [ -z "$ATLASSIAN_API_TOKEN" ]; then
        log_error "ATLASSIAN_API_TOKEN environment variable is not set"
        echo "Please set your Atlassian API token:"
        echo "export ATLASSIAN_API_TOKEN='your-api-token'"
        exit 1
    fi
    log_success "Credentials configured"
}

# Create Confluence space
create_space() {
    log_info "Creating Confluence space: $CONFLUENCE_SPACE"
    
    local space_data='{"key":"'$CONFLUENCE_SPACE'","name":"Headless WordPress + Next.js Documentation","description":{"plain":{"value":"Enterprise documentation for our headless WordPress + Next.js project with Azure deployment","representation":"plain"}},"type":"global"}'
    
    local response=$(curl -s -w "%{http_code}" \
        -X POST \
        "$CONFLUENCE_URL/wiki/rest/api/space" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$space_data")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        log_success "Space created successfully"
    elif [ "$http_code" -eq 409 ]; then
        log_info "Space already exists (conflict)"
    else
        log_error "Failed to create space. HTTP code: $http_code"
        echo "Response: $body"
    fi
}

# Create a page in Confluence
create_page() {
    local title="$1"
    local content="$2"
    local parent_id="$3"
    
    log_info "Creating page: $title"
    
    # Escape content for JSON
    local escaped_content=$(echo "$content" | sed 's/"/\\"/g' | tr -d '\n\r' | sed 's/\t/\\t/g')
    
    local page_data='{"type":"page","title":"'$title'","space":{"key":"'$CONFLUENCE_SPACE'"},"body":{"storage":{"value":"'$escaped_content'","representation":"storage"}}}'
    
    if [ -n "$parent_id" ]; then
        page_data='{"type":"page","title":"'$title'","space":{"key":"'$CONFLUENCE_SPACE'"},"body":{"storage":{"value":"'$escaped_content'","representation":"storage"}},"ancestors":[{"id":"'$parent_id'"}]}'
    fi
    
    local response=$(curl -s -w "%{http_code}" \
        -X POST \
        "$CONFLUENCE_URL/wiki/rest/api/content" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$page_data")
    
    local http_code="${response: -3}"
    local body="${response%???}"
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        log_success "Page '$title' created successfully"
        # Extract page ID from response
        echo "$body" | grep -o '"id":"[^"]*' | cut -d'"' -f4
    else
        log_error "Failed to create page '$title'. HTTP code: $http_code"
        echo "Response: $body"
        return 1
    fi
}

# Create basic page structure
create_page_structure() {
    log_info "Creating basic page structure"
    
    # Create Home page
    local home_content='<h1>Headless WordPress + Next.js Documentation</h1><p>Welcome to the comprehensive documentation for our headless WordPress + Next.js enterprise solution.</p><h2>Quick Navigation</h2><ul><li><strong>Project Overview</strong> - Strategic documentation and planning</li><li><strong>Architecture and Design</strong> - Technical architecture and system design</li><li><strong>Development</strong> - Development guides and best practices</li><li><strong>Deployment and Operations</strong> - Infrastructure and deployment procedures</li><li><strong>User Documentation</strong> - End-user guides and tutorials</li><li><strong>Templates</strong> - Documentation templates and standards</li></ul><p>This documentation is automatically synchronized from our Git repository to ensure it stays current with development.</p>'
    
    local home_id=$(create_page "Home" "$home_content")
    
    if [ -n "$home_id" ]; then
        # Create child pages
        create_page "Project Overview" "<h1>Project Overview</h1><p>Strategic documentation and project planning information.</p>" "$home_id"
        create_page "Architecture and Design" "<h1>Architecture and Design</h1><p>Technical architecture, system design, and decision records.</p>" "$home_id"
        create_page "Development" "<h1>Development</h1><p>Development guides, setup instructions, and best practices.</p>" "$home_id"
        create_page "Deployment and Operations" "<h1>Deployment and Operations</h1><p>Infrastructure, deployment procedures, and operational guides.</p>" "$home_id"
        create_page "User Documentation" "<h1>User Documentation</h1><p>End-user guides, tutorials, and help documentation.</p>" "$home_id"
        create_page "Templates" "<h1>Documentation Templates</h1><p>Standardized templates for consistent documentation.</p>" "$home_id"
    fi
}

# Main execution
main() {
    echo "🏗️  Confluence Space Setup"
    echo "========================"
    echo "Space: $CONFLUENCE_SPACE"
    echo "URL: $CONFLUENCE_URL"
    echo ""
    
    check_credentials
    create_space
    create_page_structure
    
    echo ""
    log_success "Confluence space setup complete!"
    echo ""
    echo "📍 Access your space at:"
    echo "   $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"
    echo ""
    echo "🔄 Next steps:"
    echo "1. Verify space and pages were created correctly"
    echo "2. Run documentation sync: ./sync-confluence-enhanced.sh"
    echo "3. Set up automated sync in GitHub Actions"
}

main "$@"