#!/usr/bin/env bash
# jira-comment-helpers.sh - Helper functions for Jira comment operations
#
# This module provides shared functions for adding and updating Jira comments
# to eliminate duplication between add_jira_comment() and update_jira_comment()

# Internal function to perform comment API call (add or update)
# Usage: _jira_comment_api_call <issue_key> <adf_content> <method> [comment_id]
# Returns: comment ID on success
_jira_comment_api_call() {
  local issue_key="$1"
  local adf_content="$2"
  local method="$3"        # POST or PUT
  local comment_id="$4"    # Optional, for updates

  # Construct URL
  local url="https://${ATLASSIAN_SITE_URL}/rest/api/3/issue/${issue_key}/comment"
  if [ -n "$comment_id" ]; then
    url="${url}/${comment_id}"
  fi

  # Make API call
  local response
  response=$(curl -s -w "\n%{http_code}" -u "${ATLASSIAN_USER}:${ATLASSIAN_API_TOKEN}" \
    -X "$method" \
    -H "Content-Type: application/json" \
    --data "$(cat <<EOF
{
  "body": {
    "type": "doc",
    "version": 1,
    "content": $adf_content
  }
}
EOF
)" \
    "$url")

  local http_code
  http_code=$(echo "$response" | tail -n1)
  local body
  body=$(echo "$response" | sed '$d')

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    echo "$body" | jq -r '.id'
    return 0
  else
    echo "Error: HTTP $http_code" >&2
    echo "$body" | jq '.' >&2
    return 1
  fi
}

# Prepare comment text for Jira (read file if needed, convert to ADF)
# Usage: prepare_jira_comment_text <text_or_file_path>
# Returns: ADF JSON array of paragraphs
prepare_jira_comment_text() {
  local comment_text="$1"

  # Check if comment_text is a file path and read it
  if [ -f "$comment_text" ]; then
    comment_text=$(cat "$comment_text")
  fi

  # Convert to ADF paragraphs
  _text_to_adf_paragraphs "$comment_text"
}

# Add jira-helper footer to ADF content
# Usage: add_jira_helper_footer <adf_paragraphs>
# Returns: ADF JSON with footer appended
add_jira_helper_footer() {
  local adf_paragraphs="$1"

  local footer
  footer='[{"type": "paragraph", "content": [{"type": "text", "text": ""}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Created with "}, {"type": "text", "text": "jira-helper", "marks": [{"type": "link", "attrs": {"href": "https://github.com/uniphore/platform-utilities/blob/v'$JIRA_HELPER_VERSION'/jira-helper/README.md"}}]}, {"type": "text", "text": " v'$JIRA_HELPER_VERSION' (RC)"}]}]'

  echo "$adf_paragraphs" | jq --argjson footer "$footer" '. += $footer'
}

# Validate comment parameters (common validation for add/update)
# Usage: validate_comment_params <issue_key> <comment_text> [comment_id]
# Returns: 0 if valid, 1 if invalid
validate_comment_params() {
  local issue_key="$1"
  local comment_text="$2"
  local comment_id="$3"  # Optional

  if [ -z "$issue_key" ]; then
    echo "Error: Issue key is required" >&2
    return 1
  fi

  if [ -z "$comment_text" ]; then
    echo "Error: Comment text is required" >&2
    return 1
  fi

  # If comment_id is provided (for updates), validate it
  if [ -n "$comment_id" ] && ! [[ "$comment_id" =~ ^[0-9]+$ ]]; then
    echo "Error: Comment ID must be numeric" >&2
    return 1
  fi

  return 0
}

# Check if text is a file path or inline text
# Usage: is_file_path <text>
# Returns: 0 if file exists, 1 otherwise
is_file_path() {
  [ -f "$1" ]
}

# Get comment text (from file or inline)
# Usage: get_comment_text <text_or_file_path>
# Returns: comment text
get_comment_text() {
  local input="$1"

  if is_file_path "$input"; then
    cat "$input"
  else
    echo "$input"
  fi
}

# Unified comment handler (add or update)
# Usage: _handle_jira_comment <operation> <issue_key_or_url> <comment_text> [comment_id] [--yes|--force]
# operation: "add" or "update"
# Returns: comment ID on success
_handle_jira_comment() {
  local operation="$1"
  local input="$2"
  local comment_text="$3"
  local comment_id="$4"

  # Parse issue key
  local issue_key
  issue_key=$(parse_jira_key "$input")

  # Check user relationship and confirm if needed (pass through all args for --yes/--force)
  if ! _confirm_unrelated_action "$issue_key" "$@"; then
    return 1
  fi

  # Use safe credentials loading
  _source_credentials || return 1

  # Log operation
  if [ "$operation" = "add" ]; then
    _log "Adding comment to ${issue_key}..."
  else
    _log "Updating comment ${comment_id} on ${issue_key}..."
  fi

  # Prepare comment text (handles file path or inline text, converts to ADF)
  local adf_paragraphs
  adf_paragraphs=$(prepare_jira_comment_text "$comment_text")

  # Add footer with version and link
  adf_paragraphs=$(add_jira_helper_footer "$adf_paragraphs")

  # Make API call
  local method="POST"
  local result_id

  if [ "$operation" = "update" ]; then
    method="PUT"
    result_id=$(_jira_comment_api_call "$issue_key" "$adf_paragraphs" "$method" "$comment_id")
  else
    result_id=$(_jira_comment_api_call "$issue_key" "$adf_paragraphs" "$method")
  fi

  if [ $? -eq 0 ]; then
    if [ "$operation" = "add" ]; then
      _log "✓ Comment added successfully"
    else
      _log "✓ Comment updated successfully"
    fi
    echo "$result_id"
    return 0
  else
    if [ "$operation" = "add" ]; then
      _log "✗ Failed to add comment"
    else
      _log "✗ Failed to update comment"
    fi
    return 1
  fi
}

# Build Confluence page JSON payload with proper content escaping
# Usage: _build_confluence_json <content> <title> [version] [space_key] [parent_id]
# Writes JSON to stdout
_build_confluence_json() {
  local content="$1"
  local title="$2"
  local version="$3"        # Optional - if provided, this is an update operation
  local space_key="$4"      # Optional - only for create
  local parent_id="$5"      # Optional - only for create with parent

  # Use printf + jq -Rs to preserve newlines correctly
  # -Rs reads raw input as a single string (preserving newlines)
  if [ -n "$version" ]; then
    # Update operation
    printf '%s' "$content" | jq -Rs \
      --argjson version "$version" \
      --arg title "$title" \
      '{
        version: {number: $version},
        title: $title,
        type: "page",
        body: {
          storage: {
            value: .,
            representation: "storage"
          }
        }
      }'
  else
    # Create operation
    if [ -n "$parent_id" ]; then
      printf '%s' "$content" | jq -Rs \
        --arg title "$title" \
        --arg space_key "$space_key" \
        --arg parent_id "$parent_id" \
        '{
          type: "page",
          title: $title,
          space: {key: $space_key},
          ancestors: [{id: $parent_id}],
          body: {
            storage: {
              value: .,
              representation: "storage"
            }
          }
        }'
    else
      printf '%s' "$content" | jq -Rs \
        --arg title "$title" \
        --arg space_key "$space_key" \
        '{
          type: "page",
          title: $title,
          space: {key: $space_key},
          body: {
            storage: {
              value: .,
              representation: "storage"
            }
          }
        }'
    fi
  fi
}

# Build Confluence page JSON with ADF (Atlassian Document Format) body
# Usage: _build_confluence_json_adf <adf_content> <title> [version] [space_key] [parent_id]
# Writes JSON to stdout
_build_confluence_json_adf() {
  local adf_content="$1"    # Already formatted as ADF JSON object
  local title="$2"
  local version="$3"         # Optional - if provided, this is an update operation
  local space_key="$4"       # Optional - only for create
  local parent_id="$5"       # Optional - only for create with parent

  if [ -n "$version" ]; then
    # Update operation
    jq -n \
      --argjson adf "$adf_content" \
      --argjson version "$version" \
      --arg title "$title" \
      '{
        version: {number: $version},
        title: $title,
        type: "page",
        body: {
          atlas_doc_format: {
            value: ($adf | tostring),
            representation: "atlas_doc_format"
          }
        }
      }'
  else
    # Create operation
    if [ -n "$parent_id" ]; then
      jq -n \
        --argjson adf "$adf_content" \
        --arg title "$title" \
        --arg space_key "$space_key" \
        --arg parent_id "$parent_id" \
        '{
          type: "page",
          title: $title,
          space: {key: $space_key},
          ancestors: [{id: $parent_id}],
          body: {
            atlas_doc_format: {
              value: ($adf | tostring),
              representation: "atlas_doc_format"
            }
          }
        }'
    else
      jq -n \
        --argjson adf "$adf_content" \
        --arg title "$title" \
        --arg space_key "$space_key" \
        '{
          type: "page",
          title: $title,
          space: {key: $space_key},
          body: {
            atlas_doc_format: {
              value: ($adf | tostring),
              representation: "atlas_doc_format"
            }
          }
        }'
    fi
  fi
}

# Summarize Jira comments from the time period using AI
# Usage: _summarize_jira_comments <issue_key> <comments_json> <days> [current_status] [changelog_json]
# Returns: Summary text (1-3 short sentences)
_summarize_jira_comments() {
  local issue_key="$1"
  local comments_json="$2"
  local days="$3"
  local current_status="${4:-}"
  local changelog_json="${5:-null}"

  # Extract comments from the time period and convert ADF to markdown
  local filtered_comments
  filtered_comments=$(echo "$comments_json" | jq -c --arg days "$days" '
    [.[] | select(
      .created |
      sub("\\.[0-9]+"; "") |
      sub("\\+0000$"; "Z") |
      fromdateiso8601 > (now - ($days | tonumber * 86400))
    )]
  ')

  if [ "$filtered_comments" = "[]" ] || [ -z "$filtered_comments" ]; then
    echo ""
    return 0
  fi

  # Convert each comment's ADF body to markdown
  local recent_comments="[]"
  local comment_count
  comment_count=$(echo "$filtered_comments" | jq 'length')

  for ((i=0; i<comment_count; i++)); do
    local comment_data
    comment_data=$(echo "$filtered_comments" | jq -c ".[$i]")

    local author created adf_body
    author=$(echo "$comment_data" | jq -r '.author.displayName')
    created=$(echo "$comment_data" | jq -r '.created')
    adf_body=$(echo "$comment_data" | jq -c '.body')

    # Convert ADF to markdown using the converter
    local markdown_text
    markdown_text=$(_adf_to_markdown "$adf_body")

    # Add to recent_comments array
    recent_comments=$(echo "$recent_comments" | jq --arg author "$author" \
                                                    --arg created "$created" \
                                                    --arg text "$markdown_text" \
                                                    '. += [{author: $author, created: $created, text: $text}]')
  done

  # Check if we have any non-empty comment text
  local has_content
  has_content=$(echo "$recent_comments" | jq '[.[] | select(.text != "" and .text != null)] | length')

  if [ "$has_content" -eq 0 ]; then
    echo ""
    return 0
  fi

  # Check if ticket is Blocked and when it transitioned to Blocked
  local is_blocked=false
  local blocked_transition_time=""
  if [ "$current_status" = "Blocked" ] && [ "$changelog_json" != "null" ]; then
    # Find the most recent transition to Blocked status in the timeframe
    blocked_transition_time=$(echo "$changelog_json" | jq -r --arg days "$days" '
      if .histories then
        [.histories[] |
         select(
           (.created |
            sub("\\.[0-9]+"; "") |
            sub("\\+0000$"; "Z") |
            fromdateiso8601) > (now - ($days | tonumber * 86400))
         ) |
         select(.items[] | select(.field == "status" and .toString == "Blocked")) |
         .created
        ] | sort | .[-1] // ""
      else
        ""
      end
    ')

    if [ -n "$blocked_transition_time" ]; then
      is_blocked=true
    fi
  fi

  # Use Claude to summarize
  # Create a prompt that asks for concise multi-line summary
  local blocking_instruction=""
  if [ "$is_blocked" = true ]; then
    blocking_instruction="
**IMPORTANT: This ticket is BLOCKED.** Prioritize showing WHY it's blocked from comments near $blocked_transition_time.
Look for phrases like \"blocked by\", \"waiting for\", \"awaiting approval\", \"needs\", etc.
The blocking reason should be the FIRST bullet point."
  fi

  local prompt="Summarize these Jira comments for ${issue_key}.

$recent_comments
${blocking_instruction}

OUTPUT ONLY the bullet lines below. NO preamble, NO explanations.

RULES:
- Max 10 lines if substantive, 1-2 if simple
- Each line max 10 words
- Distinguish completed work from proposals/plans
- Use past tense ONLY for completed actions
- Use \"Proposed\" or \"Investigated\" for ideas/research
- Start with dash (-)
- NO first-person

EXAMPLE OUTPUT:
- Distributed TLS cert for help.uniphore.com via platform-flux
- Created cluster-specific ClusterIssuer and validated in staging
- Proposed disabling auto-merge in repo settings
- Investigated GitHub API user-agent detection options"

  # Call Claude API (assuming ANTHROPIC_API_KEY is set)
  if [ -z "$ANTHROPIC_API_KEY" ]; then
    # Fallback: just show last comment
    echo "$recent_comments" | jq -r '[-1].text' | head -c 200
    return 0
  fi

  local summary
  summary=$(curl -s https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$(jq -n \
      --arg prompt "$prompt" \
      '{
        model: "claude-3-5-haiku-20241022",
        max_tokens: 300,
        messages: [{role: "user", content: $prompt}]
      }')" | jq -r '.content[0].text // ""')

  # Strip any preamble text and split bullets into separate lines
  # AI may return "- item1- item2- item3" all on one line, so we split on "- "
  summary=$(echo "$summary" | sed 's/^[^-]*//' | sed 's/- /\n- /g' | grep '^-' | head -10)

  if [ -n "$summary" ]; then
    # Output with preserved line breaks (no trailing newline)
    printf '%s' "$summary"
  else
    # Fallback
    local fallback
    fallback=$(echo "$recent_comments" | jq -r '[-1].text' | head -c 200)
    printf '%s' "$fallback"
  fi
}

# Get Confluence page version history and summarize changes
# Usage: _summarize_confluence_changes <page_id> <days>
# Returns: Summary text of what changed (based on content diff, not edit messages)
_summarize_confluence_changes() {
  local page_id="$1"
  local days="$2"

  # Fetch version history (limit to 50 versions to find old version)
  local versions
  versions=$(curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
    -H 'Accept: application/json' \
    "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}/version?limit=50" 2>/dev/null)

  if [ -z "$versions" ] || [ "$(echo "$versions" | jq '.results | length')" -eq 0 ]; then
    echo ""
    return 0
  fi

  # Calculate cutoff timestamp (days ago)
  local cutoff_timestamp
  cutoff_timestamp=$(date -u -v-"${days}"d +%s 2>/dev/null || date -u -d "${days} days ago" +%s)

  # Find the version that was current just before our reporting window
  local old_version_number
  old_version_number=$(echo "$versions" | jq -r --arg cutoff "$cutoff_timestamp" '
    .results |
    map({
      number: .number,
      timestamp: (.when | sub("\\.[0-9]+"; "") | sub("\\+0000$"; "Z") | fromdateiso8601)
    }) |
    # Get the latest version before the cutoff
    map(select(.timestamp < ($cutoff | tonumber))) |
    sort_by(.timestamp) |
    if length > 0 then
      .[-1].number
    else
      null
    end
  ')

  # If no old version found (page is too new), skip summary
  if [ "$old_version_number" = "null" ] || [ -z "$old_version_number" ]; then
    echo ""
    return 0
  fi

  # Get current version number
  local current_version_number
  current_version_number=$(echo "$versions" | jq -r '.results[0].number')

  # If versions are the same, no changes
  if [ "$old_version_number" = "$current_version_number" ]; then
    echo ""
    return 0
  fi

  # Fetch old and current version content
  local old_content_cache="${CACHE_DIR}/confluence-${page_id}-v${old_version_number}.txt"
  local current_content_cache="${CACHE_DIR}/confluence-${page_id}-v${current_version_number}.txt"

  # Fetch old version content (storage format as plain text)
  if [ ! -f "$old_content_cache" ]; then
    curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
      -H 'Accept: application/json' \
      "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}?version=${old_version_number}&expand=body.storage" 2>/dev/null \
      | jq -r '.body.storage.value // ""' \
      | sed 's/<[^>]*>//g' \
      > "$old_content_cache"
  fi

  # Fetch current version content
  if [ ! -f "$current_content_cache" ]; then
    curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_DOCS}" \
      -H 'Accept: application/json' \
      "https://${ATLASSIAN_SITE_URL}/wiki/rest/api/content/${page_id}?expand=body.storage" 2>/dev/null \
      | jq -r '.body.storage.value // ""' \
      | sed 's/<[^>]*>//g' \
      > "$current_content_cache"
  fi

  # Generate diff (unified format, context lines = 3)
  local diff_output
  diff_output=$(diff -u "$old_content_cache" "$current_content_cache" 2>/dev/null | head -n 200)

  # If no diff or diff is empty, no changes
  if [ -z "$diff_output" ] || [ "$(echo "$diff_output" | wc -l)" -lt 3 ]; then
    echo ""
    return 0
  fi

  # Use Claude Haiku to summarize the diff
  if [ -z "$ANTHROPIC_API_KEY" ]; then
    # Fallback: show line change stats
    local lines_added lines_removed
    lines_added=$(echo "$diff_output" | grep -c "^+" || echo "0")
    lines_removed=$(echo "$diff_output" | grep -c "^-" || echo "0")
    echo "Modified content (+${lines_added}/-${lines_removed} lines)"
    return 0
  fi

  local prompt="Summarize what changed in this Confluence page based on the content diff.

Content Diff (old version from ${days} days ago -> current):
\`\`\`diff
${diff_output}
\`\`\`

OUTPUT ONLY the bullet lines below. NO preamble, NO explanations.

RULES:
- Max 10 lines if substantive, 1-2 if simple
- Each line max 10 words
- Distinguish completed work from proposals/plans
- Use past tense for completed changes
- Start with dash (-)
- NO first-person
- Action-oriented verbs (added, updated, removed, renamed)

EXAMPLE OUTPUT:
- Added detailed architecture section for help.uniphore.com TLS
- Introduced cluster-specific resources pattern for certificate management
- Expanded Cloudflare and Route53 configuration guidance"

  local summary
  summary=$(curl -s https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d "$(jq -n \
      --arg prompt "$prompt" \
      '{
        model: "claude-3-5-haiku-20241022",
        max_tokens: 300,
        messages: [{role: "user", content: $prompt}]
      }')" | jq -r '.content[0].text // ""')

  # Strip any preamble text and split bullets into separate lines
  # AI may return "- item1- item2- item3" all on one line, so we split on "- "
  summary=$(echo "$summary" | sed 's/^[^-]*//' | sed 's/- /\n- /g' | grep '^-' | head -10)

  if [ -n "$summary" ]; then
    # Output with preserved line breaks (no trailing newline)
    printf '%s' "$summary"
  else
    # Fallback: show line change stats
    local lines_added lines_removed
    lines_added=$(echo "$diff_output" | grep -c "^+" || echo "0")
    lines_removed=$(echo "$diff_output" | grep -c "^-" || echo "0")
    printf "Modified content (+%s/-%s lines)" "$lines_added" "$lines_removed"
  fi
}
