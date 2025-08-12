#!/bin/bash

# Enhanced Confluence Documentation Sync Script
# Syncs documentation files to Confluence using Atlassian REST API and MCP integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONFLUENCE_URL="https://andylynchgranite.atlassian.net"
CONFLUENCE_SPACE="HWPSK"
DOCS_DIR="./docs"
DRY_RUN=${DRY_RUN:-false}
MODE=${MODE:-"create"}  # create, update, or full

# Logging
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to convert markdown to Confluence storage format
convert_md_to_confluence() {
    local md_file="$1"
    local output_file="$2"
    
    # This is a simplified conversion - in production you'd use a proper converter
    # For now, we'll create a basic HTML version
    log_info "Converting $md_file to Confluence format"
    
    # Extract title from frontmatter or filename
    local title
    if grep -q "^title:" "$md_file"; then
        title=$(grep "^title:" "$md_file" | sed 's/title: *"*\([^"]*\)"*/\1/')
    else
        title=$(basename "$md_file" .md | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
    fi
    
    # Create basic Confluence storage format
    cat > "$output_file" << EOF
{
  "type": "page",
  "title": "$title",
  "space": {
    "key": "$CONFLUENCE_SPACE"
  },
  "body": {
    "storage": {
      "value": "$(sed 's/"/\\"/g' "$md_file" | tr '\n' ' ' | sed 's/<ac:structured-macro[^>]*>//g')",
      "representation": "storage"
    }
  }
}
EOF
    
    log_success "Converted $md_file -> $output_file"
}

# Function to create or update page in Confluence
sync_page() {
    local md_file="$1"
    local parent_title="$2"
    local confluence_json="/tmp/confluence_page.json"
    
    log_info "Syncing $md_file"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN: Would sync $md_file to Confluence"
        return 0
    fi
    
    # Convert markdown to Confluence format
    convert_md_to_confluence "$md_file" "$confluence_json"
    
    # Extract title for the page
    local page_title
    if grep -q "^title:" "$md_file"; then
        page_title=$(grep "^title:" "$md_file" | head -1 | sed 's/title: *"*\([^"]*\)"*/\1/')
    else
        page_title=$(basename "$md_file" .md | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
    fi
    
    log_info "Page title: $page_title"
    
    # Here we would use the Confluence REST API or MCP commands
    # For now, we'll create a command that could be executed
    local curl_command="curl -X POST \
        '$CONFLUENCE_URL/wiki/rest/api/content' \
        -H 'Authorization: Bearer \$ATLASSIAN_API_TOKEN' \
        -H 'Content-Type: application/json' \
        -d @'$confluence_json'"
    
    if [ "$MODE" = "create" ]; then
        log_info "Would create page: $page_title"
        echo "$curl_command" > "/tmp/create_${page_title// /_}.sh"
    elif [ "$MODE" = "update" ]; then
        log_info "Would update page: $page_title"
        echo "$curl_command" | sed 's/POST/PUT/' > "/tmp/update_${page_title// /_}.sh"
    fi
    
    log_success "Prepared sync for: $page_title"
}

# Function to create space structure
create_space_structure() {
    log_info "Creating Confluence space structure for $CONFLUENCE_SPACE"
    
    # Define the space structure based on our documentation plan
    local pages=(
        "Home:"
        "Project Overview:Home"
        "Architecture Design:Home"
        "Development:Home"
        "Deployment Operations:Home"
        "User Documentation:Home"
        "Templates:Home"
        "Standards Processes:Home"
    )
    
    for page_def in "${pages[@]}"; do
        local page_name="${page_def%%:*}"
        local parent="${page_def##*:}"
        if [ "$parent" = "$page_name" ]; then
            parent="None"
        fi
        log_info "Would create page: $page_name (parent: $parent)"
    done
}

# Function to map documentation files to Confluence pages
map_docs_to_pages() {
    log_info "Mapping documentation files to Confluence pages"
    
    # Strategy documents
    if [ -f "$DOCS_DIR/strategy/documentation-plan.md" ]; then
        sync_page "$DOCS_DIR/strategy/documentation-plan.md" "Project Overview"
    fi
    
    # Architecture documents
    if [ -f "$DOCS_DIR/architecture/overview.md" ]; then
        sync_page "$DOCS_DIR/architecture/overview.md" "Architecture Design"
    fi
    
    # Standards documents
    if [ -f "$DOCS_DIR/standards/documentation-standards-and-processes.md" ]; then
        sync_page "$DOCS_DIR/standards/documentation-standards-and-processes.md" "Standards Processes"
    fi
    
    # Template documents
    for template in "$DOCS_DIR/templates"/*.md; do
        if [ -f "$template" ]; then
            sync_page "$template" "Templates"
        fi
    done
    
    # API documentation
    for api_doc in "$DOCS_DIR/api"/*.md; do
        if [ -f "$api_doc" ]; then
            sync_page "$api_doc" "Architecture Design"
        fi
    done
    
    # Setup and deployment docs
    for setup_doc in "$DOCS_DIR/setup"/*.md; do
        if [ -f "$setup_doc" ]; then
            sync_page "$setup_doc" "Development"
        fi
    done
    
    for deploy_doc in "$DOCS_DIR/deployment"/*.md; do
        if [ -f "$deploy_doc" ]; then
            sync_page "$deploy_doc" "Deployment Operations"
        fi
    done
}

# Main execution
main() {
    echo "🔄 Enhanced Confluence Documentation Sync"
    echo "======================================="
    log_info "Configuration:"
    echo "  Confluence URL: $CONFLUENCE_URL"
    echo "  Space Key: $CONFLUENCE_SPACE"
    echo "  Docs Directory: $DOCS_DIR"
    echo "  Mode: $MODE"
    echo "  Dry Run: $DRY_RUN"
    echo ""
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    
    if [ ! -d "$DOCS_DIR" ]; then
        log_error "Documentation directory not found: $DOCS_DIR"
        exit 1
    fi
    
    # Check MCP connection
    if ! claude mcp list | grep -q "atlassian-remote.*Connected"; then
        log_warning "Atlassian MCP server not fully connected"
        log_info "You may need to authenticate with Atlassian first"
    else
        log_success "Atlassian MCP server is connected"
    fi
    
    # Create space structure
    create_space_structure
    
    # Map and sync documentation
    map_docs_to_pages
    
    echo ""
    log_success "Sync preparation complete!"
    echo ""
    log_info "Generated files in /tmp/:"
    ls -la /tmp/create_*.sh /tmp/update_*.sh 2>/dev/null || log_warning "No API command files generated"
    
    echo ""
    log_info "Next steps:"
    echo "1. Authenticate with Atlassian (if needed)"
    echo "2. Create the Confluence space: $CONFLUENCE_SPACE"
    echo "3. Execute the generated API commands"
    echo "4. Set up automated sync in CI/CD"
    echo ""
    echo "📍 Target Confluence URL:"
    echo "   $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        --space=*)
            CONFLUENCE_SPACE="${1#*=}"
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run           Preview changes without executing"
            echo "  --mode=MODE         Sync mode: create, update, or full"
            echo "  --space=KEY         Confluence space key (default: HWPSK)"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main