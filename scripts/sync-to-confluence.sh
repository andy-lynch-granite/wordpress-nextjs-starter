#!/bin/bash

# Simple Confluence Sync Script
# Converts markdown files to basic HTML and uploads to Confluence

set -e

# Configuration
CONFLUENCE_URL="https://andylynchgranite.atlassian.net"
CONFLUENCE_SPACE="HWPSK"
ATLASSIAN_EMAIL="andrew.lynch@granite.ie"
DOCS_DIR="./docs"

# Colors
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

# Check credentials
if [ -z "$ATLASSIAN_API_TOKEN" ]; then
    log_error "ATLASSIAN_API_TOKEN not set"
    echo "Set with: export ATLASSIAN_API_TOKEN='your-token'"
    exit 1
fi

# Convert markdown to basic HTML
md_to_html() {
    local md_file="$1"
    
    # Basic markdown to HTML conversion
    sed -e 's/^# \(.*\)/<h1>\1<\/h1>/' \
        -e 's/^## \(.*\)/<h2>\1<\/h2>/' \
        -e 's/^### \(.*\)/<h3>\1<\/h3>/' \
        -e 's/^#### \(.*\)/<h4>\1<\/h4>/' \
        -e 's/^\* \(.*\)/<li>\1<\/li>/' \
        -e 's/^- \(.*\)/<li>\1<\/li>/' \
        -e 's/^\([0-9]\+\)\. \(.*\)/<li>\2<\/li>/' \
        -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
        -e 's/\*\([^*]*\)\*/<em>\1<\/em>/g' \
        -e 's/`\([^`]*\)`/<code>\1<\/code>/g' \
        "$md_file" | \
    # Wrap list items in ul tags
    sed -e ':a;N;$!ba;s/\(<li>.*<\/li>\)\n\(<li>.*<\/li>\)/\1\n\2/g' | \
    sed -e 's/\(<li>.*<\/li>\)/<ul>\1<\/ul>/g' | \
    # Add paragraph tags
    sed -e 's/^[[:space:]]*\([^<].*[^>]\)[[:space:]]*$/<p>\1<\/p>/'
}

# Get page ID by title
get_page_id() {
    local title="$1"
    
    local response=$(curl -s \
        "$CONFLUENCE_URL/wiki/rest/api/content?spaceKey=$CONFLUENCE_SPACE&title=$(echo "$title" | sed 's/ /%20/g')" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)")
    
    echo "$response" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4
}

# Update or create page
sync_page_to_confluence() {
    local md_file="$1"
    local title="$2"
    local parent_title="$3"
    
    log_info "Syncing: $title"
    
    # Extract title from frontmatter if present
    if grep -q "^title:" "$md_file"; then
        title=$(grep "^title:" "$md_file" | head -1 | sed 's/title: *"*\([^"]*\)"*/\1/')
    fi
    
    # Convert markdown to HTML
    local html_content
    html_content=$(md_to_html "$md_file")
    
    # Get parent page ID if specified
    local parent_id=""
    if [ -n "$parent_title" ]; then
        parent_id=$(get_page_id "$parent_title")
    fi
    
    # Check if page already exists
    local existing_page_id
    existing_page_id=$(get_page_id "$title")
    
    if [ -n "$existing_page_id" ]; then
        log_info "Updating existing page: $title"
        update_page "$existing_page_id" "$title" "$html_content"
    else
        log_info "Creating new page: $title"
        create_new_page "$title" "$html_content" "$parent_id"
    fi
}

# Create new page
create_new_page() {
    local title="$1"
    local content="$2"
    local parent_id="$3"
    
    local page_data='{
        "type": "page",
        "title": "'"$title"'",
        "space": {
            "key": "'"$CONFLUENCE_SPACE"'"
        },
        "body": {
            "storage": {
                "value": "'"$(echo "$content" | sed 's/"/\\"/g')"'",
                "representation": "storage"
            }
        }'
    
    if [ -n "$parent_id" ]; then
        page_data+=',
        "ancestors": [{"id": "'"$parent_id"'"}]'
    fi
    
    page_data+='}'
    
    local response=$(curl -s -w "%{http_code}" \
        -X POST \
        "$CONFLUENCE_URL/wiki/rest/api/content" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$page_data")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        log_success "Created: $title"
    else
        log_error "Failed to create: $title (HTTP: $http_code)"
    fi
}

# Update existing page
update_page() {
    local page_id="$1"
    local title="$2"
    local content="$3"
    
    # Get current version
    local version_response=$(curl -s \
        "$CONFLUENCE_URL/wiki/rest/api/content/$page_id" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)")
    
    local current_version=$(echo "$version_response" | grep -o '"number":[0-9]*' | cut -d':' -f2)
    local new_version=$((current_version + 1))
    
    local update_data='{
        "id": "'"$page_id"'",
        "type": "page",
        "title": "'"$title"'",
        "space": {
            "key": "'"$CONFLUENCE_SPACE"'"
        },
        "body": {
            "storage": {
                "value": "'"$(echo "$content" | sed 's/"/\\"/g')"'",
                "representation": "storage"
            }
        },
        "version": {
            "number": '"$new_version"'
        }
    }'
    
    local response=$(curl -s -w "%{http_code}" \
        -X PUT \
        "$CONFLUENCE_URL/wiki/rest/api/content/$page_id" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$update_data")
    
    local http_code="${response: -3}"
    
    if [ "$http_code" -eq 200 ]; then
        log_success "Updated: $title"
    else
        log_error "Failed to update: $title (HTTP: $http_code)"
    fi
}

# Main sync function
main() {
    echo "🔄 Syncing Documentation to Confluence"
    echo "======================================"
    echo "Space: $CONFLUENCE_SPACE"
    echo ""
    
    # Sync main documents
    if [ -f "$DOCS_DIR/strategy/documentation-plan.md" ]; then
        sync_page_to_confluence "$DOCS_DIR/strategy/documentation-plan.md" "Documentation Strategy Plan" "Project Overview"
    fi
    
    if [ -f "$DOCS_DIR/architecture/overview.md" ]; then
        sync_page_to_confluence "$DOCS_DIR/architecture/overview.md" "System Architecture Overview" "Architecture & Design"
    fi
    
    if [ -f "$DOCS_DIR/standards/documentation-standards-and-processes.md" ]; then
        sync_page_to_confluence "$DOCS_DIR/standards/documentation-standards-and-processes.md" "Documentation Standards and Processes" "Templates"
    fi
    
    # Sync templates
    for template in "$DOCS_DIR/templates"/*.md; do
        if [ -f "$template" ]; then
            local template_name=$(basename "$template" .md | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
            sync_page_to_confluence "$template" "$template_name Template" "Templates"
        fi
    done
    
    echo ""
    log_success "Documentation sync complete!"
    echo ""
    echo "📍 View at: $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"
}

main "$@"