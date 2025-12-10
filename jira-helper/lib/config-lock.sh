#!/usr/bin/env bash
# config-lock.sh - Lockfile utilities for .claude/config updates
#
# Provides safe, atomic config file updates with lockfile protection
# to prevent race conditions when multiple processes try to update simultaneously

CLAUDE_CONFIG_LOCK="${HOME}/.claude/.config.lock"
LOCK_TIMEOUT=30  # seconds
LOCK_WAIT_INTERVAL=0.5  # seconds between retry attempts

# Acquire lock for config file modification
# Returns: 0 on success, 1 on timeout
# Usage: _acquire_config_lock || { echo "Failed to acquire lock"; return 1; }
_acquire_config_lock() {
  local waited=0
  local lock_pid

  while [ $waited -lt $LOCK_TIMEOUT ]; do
    # Try to create lock file atomically
    if mkdir "$CLAUDE_CONFIG_LOCK" 2>/dev/null; then
      # Successfully created lock directory
      echo $$ > "${CLAUDE_CONFIG_LOCK}/pid"
      echo "$(date +%s)" > "${CLAUDE_CONFIG_LOCK}/timestamp"
      return 0
    fi

    # Lock exists - check if it's stale
    if [ -f "${CLAUDE_CONFIG_LOCK}/pid" ]; then
      lock_pid=$(cat "${CLAUDE_CONFIG_LOCK}/pid" 2>/dev/null || echo "")

      # Check if the process holding the lock still exists
      if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
        # Process is dead, remove stale lock
        _release_config_lock "$lock_pid" 2>/dev/null || true
        continue  # Try again
      fi
    fi

    # Check if lock is too old (stale)
    if [ -f "${CLAUDE_CONFIG_LOCK}/timestamp" ]; then
      local lock_time
      lock_time=$(cat "${CLAUDE_CONFIG_LOCK}/timestamp" 2>/dev/null || echo "0")
      local current_time
      current_time=$(date +%s)
      local age=$((current_time - lock_time))

      if [ $age -gt $LOCK_TIMEOUT ]; then
        # Lock is stale, remove it
        _release_config_lock "${lock_pid:-stale}" 2>/dev/null || true
        continue  # Try again
      fi
    fi

    # Lock is held by active process, wait and retry
    sleep $LOCK_WAIT_INTERVAL
    waited=$(echo "$waited + $LOCK_WAIT_INTERVAL" | bc)
  done

  # Timeout reached
  echo "ERROR: Timeout waiting for config lock after ${LOCK_TIMEOUT}s" >&2
  if [ -f "${CLAUDE_CONFIG_LOCK}/pid" ]; then
    lock_pid=$(cat "${CLAUDE_CONFIG_LOCK}/pid" 2>/dev/null || echo "unknown")
    echo "  Lock held by PID: $lock_pid" >&2
  fi
  return 1
}

# Release lock for config file modification
# Usage: _release_config_lock [pid]
_release_config_lock() {
  local expected_pid="${1:-$$}"

  if [ ! -d "$CLAUDE_CONFIG_LOCK" ]; then
    return 0  # Lock doesn't exist, nothing to do
  fi

  # Verify we own the lock (unless we're cleaning up a stale lock)
  if [ "$expected_pid" = "$$" ] && [ -f "${CLAUDE_CONFIG_LOCK}/pid" ]; then
    local lock_pid
    lock_pid=$(cat "${CLAUDE_CONFIG_LOCK}/pid" 2>/dev/null || echo "")
    if [ "$lock_pid" != "$$" ] && [ "$lock_pid" != "$expected_pid" ]; then
      echo "WARNING: Not releasing lock owned by PID $lock_pid (we are $$)" >&2
      return 1
    fi
  fi

  # Remove lock
  rm -rf "$CLAUDE_CONFIG_LOCK"
  return 0
}

# Update Claude config with BEGIN/END managed section
# This is the main function to safely update the jira-helper section
# Usage: _update_claude_config
_update_claude_config() {
  local jira_helper_path="${1:-${HOME}/.jira-helper/jira-helper.sh}"
  local claude_config="${HOME}/.claude/config"

  # Check if config exists
  if [ ! -f "$claude_config" ]; then
    echo "ERROR: Claude config not found at $claude_config" >&2
    return 1
  fi

  # Acquire lock
  if ! _acquire_config_lock; then
    echo "ERROR: Failed to acquire lock for config update" >&2
    return 1
  fi

  # Ensure lock is released on exit
  trap '_release_config_lock' EXIT INT TERM

  # Backup existing config
  local backup_dir="${HOME}/.claude/.backups"
  mkdir -p "$backup_dir"
  local backup_file="${backup_dir}/config.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$claude_config" "$backup_file"

  # Create temp file with new section
  local temp_config
  temp_config=$(mktemp)

  # Extract everything before the Atlassian policy section
  awk '/^## (Atlassian policy|jira-helper)/{exit} {print}' "$claude_config" > "$temp_config"

  # Add updated Atlassian policy section with BEGIN/END markers
  cat >> "$temp_config" <<EOF

## Atlassian policy
# BEGIN jira-helper managed section - do not edit between BEGIN/END markers
export JIRA_HELPER_PATH="${jira_helper_path}"
- CRITICAL: For Jira/Confluence, use jira-helper.sh functions when available.
- ALWAYS source jira-helper.sh BEFORE calling any jira-helper function: source "\$JIRA_HELPER_PATH" 2>/dev/null
- Pattern: source ~/.jira-helper/jira-helper.sh && get_confluence_page 4220125196
- NEVER source from ~/repos/platform-utilities/jira-helper/ (dev path) - use ~/.jira-helper/ (installed path)
- NEVER modify ~/.jira (credentials file). Only read from it.
- Do not hand-roll curl for Atlassian if a jira-helper function exists.
- Cache file reads are allowed: Read(\$HOME/.jira-helper/**) and Read(\$HOME/.jira-helper/.atlassian-cache/**)
- Always write API responses to a cache file. Do not pipe curl output directly to jq.
  - Pattern: \`curl ... -o cache.json 2>/dev/null\`, then \`jq ... cache.json\`.
- NEVER use MCP Atlassian tools (mcp__atlassian* or mcp__atlassian-official*).
- For Atlassian operations, ONLY use jira-helper.sh functions.

**Credential Variables (from ~/.jira):**
- Use ATLASSIAN_USER (NOT ATLASSIAN_EMAIL)
- Use ATLASSIAN_API_TOKEN
- Use ATLASSIAN_SITE_URL
- To load: source ~/.jira-helper/jira-helper.sh && _source_credentials

**Function Discovery:**
- Quick reference: Read(\$HOME/.jira-helper/QUICKREF.txt) - READ THIS FIRST for available functions
- Full help: source ~/.jira-helper/jira-helper.sh && jira_helper help
- List functions: declare -F | grep -E 'jira_|confluence_|eod_'

**Markdown file locations:**
- ALWAYS use ~/markdowns/ (not ~/MyDocuments/markdowns/) for jira-helper related markdown files
- EOD reports go to: ~/markdowns/EOD-YYYY-MM-DD.md
- Jira issue documentation: ~/markdowns/TICKET-123.md
- Confluence content source: ~/markdowns/ (for replace_confluence_page conversions)

**Markdown syntax for Jira comments/descriptions:**
- Use standard markdown, NOT Confluence wiki markup
- Code blocks: \`\`\`language (NOT {code:language})
- Inline code: \`code\` (NOT {{code}})
- Bold: **text** (NOT *text*)
- Italic: *text* (NOT _text_)
- URLs: Just paste the URL (jira-helper converts to clickable links automatically)
- Lists: - item or 1. item (standard markdown)

**CRITICAL - Do NOT invent flags:**
- Supported flags: --yes / --force (bypass confirmations), --json (get_jira_issue only)
- Do NOT use unsupported flags like --open, --verbose, etc.
- jira-helper issue TICKET-123 displays the issue and prints the URL - use separate open command to open in browser
- When in doubt, check jira_helper help first

Error handling:
- If a jira-helper function fails, check the function's help or report the issue.
- Do not silently fall back to raw curl.
# END jira-helper managed section
EOF

  # Extract user custom directives and any content after the managed section
  if grep -q "# END jira-helper managed section" "$claude_config" 2>/dev/null; then
    # Has END marker - preserve content after it until next ## heading
    awk '/# END jira-helper managed section/{found=1; next} found && /^##/{exit} found{print}' "$claude_config" >> "$temp_config"
    # Also preserve any content from next ## heading to end
    awk '/# END jira-helper managed section/{found=1} found && /^##/{found=0} !found && NR>1{print}' "$claude_config" >> "$temp_config"
  else
    # No END marker - preserve content after old section heading
    awk '/^## (Atlassian policy|jira-helper)/{found=1; next} found && /^##/{exit} found{print}' "$claude_config" >> "$temp_config"
    # Preserve everything from next ## heading to end
    awk '/^## (Atlassian policy|jira-helper)/{found=1; next} found && /^##/{found=0} !found{print}' "$claude_config" >> "$temp_config"
  fi

  # Atomically replace config file (mv is atomic on same filesystem)
  mv "$temp_config" "$claude_config"

  # Release lock (trap will also handle this)
  _release_config_lock
  trap - EXIT INT TERM

  echo "✓ Updated Claude config (backed up to $backup_file)"
  return 0
}

# Export functions for use in other scripts
export -f _acquire_config_lock
export -f _release_config_lock
export -f _update_claude_config
