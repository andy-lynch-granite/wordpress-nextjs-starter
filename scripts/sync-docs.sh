#!/bin/bash

# Sync Documentation Content to Confluence
set -e

CONFLUENCE_URL="https://andylynchgranite.atlassian.net"
CONFLUENCE_SPACE="HWPSK"
ATLASSIAN_EMAIL="andrew.lynch@granite.ie"

if [ -z "$ATLASSIAN_API_TOKEN" ]; then
    echo "Error: ATLASSIAN_API_TOKEN not set"
    exit 1
fi

echo "Syncing documentation to Confluence..."

# Function to get page ID by title
get_page_id() {
    local title="$1"
    local encoded_title=$(echo "$title" | sed 's/ /%20/g')
    
    curl -s \
        "$CONFLUENCE_URL/wiki/rest/api/content?spaceKey=$CONFLUENCE_SPACE&title=$encoded_title" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" | \
    grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4
}

# Function to convert markdown to basic HTML
md_to_html() {
    local file="$1"
    
    # Remove frontmatter
    sed '/^---$/,/^---$/d' "$file" | \
    # Convert headers
    sed -e 's/^# \(.*\)/<h1>\1<\/h1>/' \
        -e 's/^## \(.*\)/<h2>\1<\/h2>/' \
        -e 's/^### \(.*\)/<h3>\1<\/h3>/' \
        -e 's/^#### \(.*\)/<h4>\1<\/h4>/' \
        -e 's/^\* \(.*\)/<li>\1<\/li>/' \
        -e 's/^- \(.*\)/<li>\1<\/li>/' \
        -e 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' \
        -e 's/`\([^`]*\)`/<code>\1<\/code>/g' | \
    # Add paragraph tags to regular lines
    sed -e 's/^\([^<].*[^>]\)$/<p>\1<\/p>/' | \
    # Remove empty lines
    grep -v '^$'
}

# Function to update page content
update_page() {
    local title="$1"
    local content="$2"
    
    echo "Updating: $title"
    
    local page_id=$(get_page_id "$title")
    
    if [ -z "$page_id" ]; then
        echo "  Page not found, skipping"
        return
    fi
    
    # Get current version
    local version_info=$(curl -s \
        "$CONFLUENCE_URL/wiki/rest/api/content/$page_id" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)")
    
    local current_version=$(echo "$version_info" | grep -o '"number":[0-9]*' | cut -d':' -f2)
    local new_version=$((current_version + 1))
    
    # Escape content for JSON
    local escaped_content=$(echo "$content" | sed 's/"/\\"/g' | tr '\n' ' ')
    
    # Update page
    local update_payload=$(cat <<EOF
{
  "id": "$page_id",
  "type": "page",
  "title": "$title",
  "space": {"key": "$CONFLUENCE_SPACE"},
  "body": {
    "storage": {
      "value": "$escaped_content",
      "representation": "storage"
    }
  },
  "version": {"number": $new_version}
}
EOF
)
    
    curl -X PUT \
        "$CONFLUENCE_URL/wiki/rest/api/content/$page_id" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$update_payload" \
        -s -o /dev/null -w "  HTTP %{http_code}\n"
}

# Sync documentation files
if [ -f "docs/strategy/documentation-plan.md" ]; then
    html_content=$(md_to_html "docs/strategy/documentation-plan.md")
    update_page "Project Overview" "$html_content"
fi

if [ -f "docs/architecture/overview.md" ]; then
    html_content=$(md_to_html "docs/architecture/overview.md")  
    update_page "Architecture Overview" "$html_content"
fi

echo "Documentation sync complete!"
echo "Visit: $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"