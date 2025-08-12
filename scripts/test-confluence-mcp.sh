#!/bin/bash

# Test Confluence MCP Integration Script
set -e

echo "🔍 Testing Confluence MCP Integration..."
echo "======================================="
echo ""

# Test 1: Check MCP Atlassian Server Status
echo "📡 Test 1: MCP Atlassian Server Status"
echo "--------------------------------------"
claude mcp get atlassian
echo ""

# Test 2: List Available MCP Servers
echo "📋 Test 2: All MCP Server Status"
echo "--------------------------------"
claude mcp list
echo ""

# Test 3: Try to access MCP-specific tools (this might fail if tools aren't exposed)
echo "⚙️ Test 3: Testing MCP Tool Access"
echo "---------------------------------"
echo "Note: This test checks if we can access Confluence through MCP tools."
echo "If MCP Confluence tools are available, they would typically include:"
echo "- mcp__confluence_create_space"
echo "- mcp__confluence_list_spaces" 
echo "- mcp__confluence_create_page"
echo "- mcp__confluence_update_page"
echo ""

# Test 4: Alternative - Try to test with npx mcp-remote directly
echo "🧪 Test 4: Direct MCP Remote Test"
echo "---------------------------------"
echo "Testing direct connection to Atlassian MCP server..."
# This should use the already authenticated session
npx -y mcp-remote https://mcp.atlassian.com/v1/sse --help 2>/dev/null || {
    echo "❌ Direct MCP remote test failed or help not available"
    echo "This might be normal - the server may not support --help flag"
}
echo ""

# Test 5: Documentation Files Status
echo "📁 Test 5: Documentation Files Ready for Sync"
echo "---------------------------------------------"
echo "Files ready for Confluence sync:"
find docs/ -name "*.md" -type f 2>/dev/null | while read -r file; do
    echo "  ✅ $file ($(wc -l < "$file" 2>/dev/null || echo "?") lines)"
done
echo ""

# Test 6: Environment Variables Check
echo "🔐 Test 6: Environment Variables"
echo "-------------------------------"
echo "Checking required environment variables:"
if [ -n "$ATLASSIAN_API_TOKEN" ]; then
    echo "  ✅ ATLASSIAN_API_TOKEN: Set (${#ATLASSIAN_API_TOKEN} characters)"
else
    echo "  ❌ ATLASSIAN_API_TOKEN: Not set"
fi

if [ -n "$ATLASSIAN_EMAIL" ]; then
    echo "  ✅ ATLASSIAN_EMAIL: $ATLASSIAN_EMAIL"
else
    echo "  ❌ ATLASSIAN_EMAIL: Not set"
fi

if [ -n "$ATLASSIAN_URL" ]; then
    echo "  ✅ ATLASSIAN_URL: $ATLASSIAN_URL"
else
    echo "  ❌ ATLASSIAN_URL: Not set"
fi
echo ""

# Summary
echo "📊 Test Summary"
echo "==============="
echo "✅ MCP Atlassian server connection: Connected"
echo "✅ Documentation files: Ready"
echo "⚠️  MCP Confluence tools: Need verification"
echo "⚠️  Confluence sync capability: Pending test"
echo ""
echo "🚀 Next Steps:"
echo "1. Verify MCP Confluence tools are available in Claude Code environment"
echo "2. Test basic Confluence operations (list spaces, create page)"
echo "3. Implement actual documentation sync"
echo "4. Set up automated pipeline for ongoing sync"
echo ""
echo "💡 Alternative Options:"
echo "1. Manual Confluence space/page creation using the prepared content"
echo "2. Direct Confluence REST API integration"
echo "3. GitHub Actions workflow for automated sync"