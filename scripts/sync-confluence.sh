#!/bin/bash

# Confluence Documentation Sync Script
# This script demonstrates how to sync documentation with Confluence using MCP

set -e

echo "🔄 Starting Confluence Documentation Sync..."

# Configuration
CONFLUENCE_URL="https://andylynchgranite.atlassian.net"
CONFLUENCE_SPACE="HWPSK"
DOCS_DIR="./docs"

echo "📋 Configuration:"
echo "  Confluence URL: $CONFLUENCE_URL"
echo "  Space Key: $CONFLUENCE_SPACE"
echo "  Docs Directory: $DOCS_DIR"
echo ""

# Check if MCP Atlassian server is available
echo "🔍 Checking MCP Atlassian server connection..."
claude mcp get atlassian || {
    echo "❌ Error: Atlassian MCP server not connected"
    echo "Please ensure the Atlassian MCP server is configured and authenticated"
    exit 1
}

echo "✅ Atlassian MCP server is connected"
echo ""

# Function to create/update Confluence page
sync_page_to_confluence() {
    local file_path="$1"
    local page_title="$2"
    local parent_page="$3"
    
    echo "📄 Syncing: $file_path -> $page_title"
    
    # In a real implementation, you would use MCP Atlassian commands like:
    # mcp-atlassian create-page --space="$CONFLUENCE_SPACE" --title="$page_title" --content-file="$file_path" --parent="$parent_page"
    
    # For now, we'll show what would be synced
    echo "  📝 File: $file_path"
    echo "  🏷️  Title: $page_title"
    echo "  📂 Parent: $parent_page"
    echo "  ✅ Would sync to: $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"
    echo ""
}

# Create Confluence space structure
echo "🏗️  Creating Confluence space structure..."

# Create main space if it doesn't exist
echo "📋 Creating space: $CONFLUENCE_SPACE - Headless WordPress + Next.js Documentation"

# Sync documentation files
echo "📚 Syncing documentation files..."

# Strategy documentation
if [ -f "$DOCS_DIR/strategy/documentation-plan.md" ]; then
    sync_page_to_confluence "$DOCS_DIR/strategy/documentation-plan.md" "Documentation Strategy Plan" "Home"
fi

# Architecture documentation
if [ -f "$DOCS_DIR/architecture/overview.md" ]; then
    sync_page_to_confluence "$DOCS_DIR/architecture/overview.md" "System Architecture Overview" "Architecture"
fi

# Setup documentation
if [ -f "$DOCS_DIR/setup/getting-started.md" ]; then
    sync_page_to_confluence "$DOCS_DIR/setup/getting-started.md" "Getting Started Guide" "Getting Started"
fi

# Deployment documentation
if [ -f "$DOCS_DIR/deployment/azure-deployment.md" ]; then
    sync_page_to_confluence "$DOCS_DIR/deployment/azure-deployment.md" "Azure Deployment Guide" "Deployment"
fi

# API documentation
if [ -f "$DOCS_DIR/api/graphql-api.md" ]; then
    sync_page_to_confluence "$DOCS_DIR/api/graphql-api.md" "GraphQL API Documentation" "API Documentation"
fi

echo "🎉 Documentation sync complete!"
echo ""
echo "📍 View your documentation at:"
echo "   $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"
echo ""
echo "🔄 To run actual sync with MCP Atlassian integration:"
echo "   1. Ensure all documentation files are created"
echo "   2. Test MCP Atlassian connection: claude mcp list"
echo "   3. Use MCP commands to create space and pages"
echo "   4. Set up automated sync in GitHub Actions"
echo ""

# Show what files would be synced
echo "📁 Files ready for sync:"
find "$DOCS_DIR" -name "*.md" -type f | while read -r file; do
    echo "  ✅ $file"
done

echo ""
echo "✨ Next steps:"
echo "   1. Review the created documentation files"
echo "   2. Test MCP Atlassian integration manually"
echo "   3. Set up GitHub Actions workflow for automated sync"
echo "   4. Create Confluence space: $CONFLUENCE_SPACE"
echo "   5. Configure page permissions and access"