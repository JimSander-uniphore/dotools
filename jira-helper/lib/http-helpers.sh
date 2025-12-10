#!/bin/bash
# HTTP Helper Functions for Atlassian API calls
# Provides reusable wrappers for REST API operations
#
# All functions follow a consistent pattern:
# - Handle authentication automatically
# - Parse HTTP status codes
# - Return body on success, error message on failure
# - Exit code 0 on success, 1 on failure

# Make a GET request to Atlassian API
# Usage: atlassian_api_get <url> [credential_var]
# Returns: Response body on success (200-299), error on failure
# credential_var: ATLASSIAN_API_TOKEN (default) or ATLASSIAN_DOCS (for Confluence)
atlassian_api_get() {
  local url="$1"
  local cred_var="${2:-ATLASSIAN_API_TOKEN}"

  # Select credential based on parameter
  local credential
  if [ "$cred_var" = "ATLASSIAN_DOCS" ]; then
    credential="${ATLASSIAN_DOCS}"
  else
    credential="${ATLASSIAN_API_TOKEN}"
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${ATLASSIAN_USER}:${credential}" \
    -H "Accept: application/json" \
    "$url")

  _parse_http_response "$response"
}

# Make a POST request to Atlassian API
# Usage: atlassian_api_post <url> <json_data> [credential_var]
# Returns: Response body on success (200-299), error on failure
atlassian_api_post() {
  local url="$1"
  local data="$2"
  local cred_var="${3:-ATLASSIAN_API_TOKEN}"

  # Select credential based on parameter
  local credential
  if [ "$cred_var" = "ATLASSIAN_DOCS" ]; then
    credential="${ATLASSIAN_DOCS}"
  else
    credential="${ATLASSIAN_API_TOKEN}"
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${ATLASSIAN_USER}:${credential}" \
    -X POST \
    -H "Content-Type: application/json" \
    --data "$data" \
    "$url")

  _parse_http_response "$response"
}

# Make a PUT request to Atlassian API
# Usage: atlassian_api_put <url> <json_data> [credential_var]
# Returns: Response body on success (200-299), error on failure
atlassian_api_put() {
  local url="$1"
  local data="$2"
  local cred_var="${3:-ATLASSIAN_API_TOKEN}"

  # Select credential based on parameter
  local credential
  if [ "$cred_var" = "ATLASSIAN_DOCS" ]; then
    credential="${ATLASSIAN_DOCS}"
  else
    credential="${ATLASSIAN_API_TOKEN}"
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${ATLASSIAN_USER}:${credential}" \
    -X PUT \
    -H "Content-Type: application/json" \
    --data "$data" \
    "$url")

  _parse_http_response "$response"
}

# Make a DELETE request to Atlassian API
# Usage: atlassian_api_delete <url> [credential_var]
# Returns: Response body on success (200-299), error on failure
atlassian_api_delete() {
  local url="$1"
  local cred_var="${2:-ATLASSIAN_API_TOKEN}"

  # Select credential based on parameter
  local credential
  if [ "$cred_var" = "ATLASSIAN_DOCS" ]; then
    credential="${ATLASSIAN_DOCS}"
  else
    credential="${ATLASSIAN_API_TOKEN}"
  fi

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${ATLASSIAN_USER}:${credential}" \
    -X DELETE \
    -H "Accept: application/json" \
    "$url")

  _parse_http_response "$response"
}

# Internal: Parse HTTP response (status code + body)
# Usage: _parse_http_response <curl_response>
# Returns: Body on success, error message on failure
# Exit code: 0 on success (200-299), 1 on failure
_parse_http_response() {
  local response="$1"

  local http_code
  http_code=$(echo "$response" | tail -n1)

  local body
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "$body"
    return 0
  else
    # Try to extract error message from JSON response
    local error_msg
    error_msg=$(echo "$body" | jq -r '.errorMessages[]? // .message? // empty' 2>/dev/null | head -1)

    if [ -n "$error_msg" ]; then
      echo "Error: HTTP $http_code - $error_msg" >&2
    else
      echo "Error: HTTP $http_code" >&2
      echo "$body" >&2
    fi
    return 1
  fi
}

# Build Jira REST API URL
# Usage: jira_api_url <endpoint>
# Example: jira_api_url "issue/PROJ-123"
# Returns: Full URL string
jira_api_url() {
  local endpoint="$1"
  echo "https://${ATLASSIAN_SITE_URL}/rest/api/3/${endpoint}"
}

# Build Confluence REST API URL
# Usage: confluence_api_url <endpoint>
# Example: confluence_api_url "content/12345"
# Returns: Full URL string
confluence_api_url() {
  local endpoint="$1"
  echo "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/${endpoint}"
}

# Validate Atlassian credentials are configured
# Usage: require_atlassian_credentials
# Returns: 0 if valid, 1 if missing (with error message)
require_atlassian_credentials() {
  if [ -z "$ATLASSIAN_USER" ] || [ -z "$ATLASSIAN_API_TOKEN" ] || [ -z "$ATLASSIAN_SITE_URL" ]; then
    echo "Error: Atlassian credentials not configured" >&2
    echo "Please set up ~/.jira file with required credentials:" >&2
    echo "  ATLASSIAN_USER, ATLASSIAN_API_TOKEN, ATLASSIAN_SITE_URL" >&2
    return 1
  fi
  return 0
}

# Check if Confluence credentials are available
# Usage: has_confluence_credentials
# Returns: 0 if available, 1 if not
has_confluence_credentials() {
  [ -n "$ATLASSIAN_DOCS" ]
}
