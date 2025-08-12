#!/bin/bash

# Simple Confluence Page Creator
set -e

CONFLUENCE_URL="https://andylynchgranite.atlassian.net"
CONFLUENCE_SPACE="HWPSK"
ATLASSIAN_EMAIL="andrew.lynch@granite.ie"

# Check credentials
if [ -z "$ATLASSIAN_API_TOKEN" ]; then
    echo "Error: ATLASSIAN_API_TOKEN not set"
    exit 1
fi

echo "Creating Confluence pages..."

# Create a simple page
create_simple_page() {
    local title="$1"
    local content="$2"
    
    echo "Creating: $title"
    
    # Simple JSON payload
    local json_payload=$(cat <<EOF
{
  "type": "page",
  "title": "$title",
  "space": {"key": "$CONFLUENCE_SPACE"},
  "body": {
    "storage": {
      "value": "$content",
      "representation": "storage"
    }
  }
}
EOF
)
    
    curl -X POST \
        "$CONFLUENCE_URL/wiki/rest/api/content" \
        -H "Authorization: Basic $(echo -n "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" | base64)" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        -s -o /dev/null -w "HTTP %{http_code}\n"
}

# Create pages
create_simple_page "Documentation Home" "<h1>Documentation Home</h1><p>Welcome to our project documentation.</p>"
create_simple_page "Project Overview" "<h1>Project Overview</h1><p>Strategic documentation and project planning.</p>"
create_simple_page "Architecture Overview" "<h1>Architecture Overview</h1><p>Technical architecture and system design.</p>"

echo "Pages created successfully!"
echo "Visit: $CONFLUENCE_URL/wiki/spaces/$CONFLUENCE_SPACE"