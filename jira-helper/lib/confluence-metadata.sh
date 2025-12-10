#!/usr/bin/env bash
# confluence-metadata.sh - Confluence page metadata detection
#
# Provides functions to detect if pages were created/managed by jira-helper

# Check if a Confluence page was created by jira-helper
# Usage: is_managed_by_jira_helper <page-id>
# Returns: 0 if managed by jira-helper, 1 otherwise
is_managed_by_jira_helper() {
  local page_id="$1"

  if [ -z "$page_id" ]; then
    echo "Error: Usage: is_managed_by_jira_helper <page-id>" >&2
    return 1
  fi

  _source_credentials || return 1

  # Check for jira-helper-managed property using Content Properties API
  local property_value
  property_value=$(curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
    "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}/property/jira-helper-managed" \
    2>/dev/null | jq -r '.value.managed' 2>/dev/null)

  if [ "$property_value" = "true" ]; then
    return 0  # Managed by jira-helper
  else
    return 1  # Not managed by jira-helper
  fi
}

# Get metadata from a jira-helper managed page
# Usage: get_jira_helper_metadata <page-id>
# Returns: JSON with metadata fields
get_jira_helper_metadata() {
  local page_id="$1"

  if [ -z "$page_id" ]; then
    echo "Error: Usage: get_jira_helper_metadata <page-id>" >&2
    return 1
  fi

  _source_credentials || return 1

  # Fetch jira-helper-managed property using Content Properties API
  local property_json
  property_json=$(curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
    "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}/property/jira-helper-managed" \
    2>/dev/null)

  # Check if property exists
  local status_code=$(echo "$property_json" | jq -r '.statusCode // 200' 2>/dev/null)
  if [ "$status_code" != "200" ]; then
    echo "{\"managed\": false}"
    return 0
  fi

  # Extract and return the metadata value
  local metadata=$(echo "$property_json" | jq -r '.value' 2>/dev/null)
  if [ -z "$metadata" ] || [ "$metadata" = "null" ]; then
    echo "{\"managed\": false}"
    return 0
  fi

  echo "$metadata"
}

# Set metadata for a jira-helper managed page
# Usage: set_jira_helper_metadata <page-id> <source-info>
# Returns: 0 if successful, 1 otherwise
set_jira_helper_metadata() {
  local page_id="$1"
  local source_info="$2"

  if [ -z "$page_id" ]; then
    echo "Error: Usage: set_jira_helper_metadata <page-id> <source-info>" >&2
    return 1
  fi

  _source_credentials || return 1

  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Build metadata JSON
  local metadata_json=$(jq -n \
    --arg managed "true" \
    --arg managed_by "jira-helper" \
    --arg updated "$timestamp" \
    --arg source "$source_info" \
    '{managed: ($managed == "true"), managed_by: $managed_by, updated: $updated, source: $source}')

  # Check if property already exists
  local existing_property
  existing_property=$(curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
    "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}/property/jira-helper-managed" \
    2>/dev/null)

  local property_version
  property_version=$(echo "$existing_property" | jq -r '.version.number // 0' 2>/dev/null)

  # Build property update JSON
  local property_payload
  if [ "$property_version" = "0" ]; then
    # Create new property
    property_payload=$(jq -n \
      --argjson value "$metadata_json" \
      '{key: "jira-helper-managed", value: $value}')
  else
    # Update existing property
    property_payload=$(jq -n \
      --argjson value "$metadata_json" \
      --argjson version "$((property_version + 1))" \
      '{key: "jira-helper-managed", value: $value, version: {number: $version}}')
  fi

  # Set or update the property
  local temp_file="${CACHE_DIR}/property-update-$$.json"
  echo "$property_payload" > "$temp_file"

  local response
  if [ "$property_version" = "0" ]; then
    # POST to create
    response=$(curl -s -X POST \
      -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
      -H "Content-Type: application/json" \
      -d @"$temp_file" \
      "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}/property" \
      2>/dev/null)
  else
    # PUT to update
    response=$(curl -s -X PUT \
      -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
      -H "Content-Type: application/json" \
      -d @"$temp_file" \
      "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}/property/jira-helper-managed" \
      2>/dev/null)
  fi

  rm -f "$temp_file"

  # Check if successful
  local new_version=$(echo "$response" | jq -r '.version.number' 2>/dev/null)
  if [ -n "$new_version" ] && [ "$new_version" != "null" ]; then
    return 0
  else
    _log "Warning: Failed to set metadata property for page $page_id"
    return 1
  fi
}

# Warn user if attempting to edit a page not managed by jira-helper
# Usage: warn_if_not_managed <page-id>
# Returns: 0 if OK to proceed, 1 if user declines
warn_if_not_managed() {
  local page_id="$1"

  if [ -z "$page_id" ]; then
    return 0  # No page ID, proceed
  fi

  if is_managed_by_jira_helper "$page_id"; then
    _log "Page $page_id is managed by jira-helper ✓"
    return 0
  fi

  # Page is NOT managed by jira-helper - warn user
  echo ""
  echo "⚠️  WARNING: This Confluence page was NOT created by jira-helper"
  echo ""
  echo "   Replacing a manually created page with markdown may:"
  echo "   - Overwrite custom Confluence macros"
  echo "   - Lose formatting that doesn't translate to markdown"
  echo "   - Replace collaborative edits made directly in Confluence"
  echo ""
  echo "   Best practice: Only use jira-helper for pages that were"
  echo "   created via jira-helper (markdown as source of truth)."
  echo ""
  read -p "   Continue anyway? (y/N): " -n 1 -r
  echo ""

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Operation cancelled"
    return 1
  fi

  echo "✓ Proceeding with replacement"
  return 0
}
