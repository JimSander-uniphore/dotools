#!/bin/bash
# Cache Helper Functions for jira-helper
# Provides reusable cache operations for API responses
#
# All functions work with the global CACHE_DIR variable
# Cache files are JSON format with metadata

# Get cached data if it exists
# Usage: cache_get <cache_key>
# Returns: Cached data if exists, empty if not
# Exit code: 0 if found, 1 if not found
cache_get() {
  local cache_key="$1"
  local cache_file="${CACHE_DIR}/${cache_key}.json"

  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi
  return 1
}

# Save data to cache
# Usage: cache_set <cache_key> <data>
# Returns: Nothing
# Exit code: Always 0
cache_set() {
  local cache_key="$1"
  local data="$2"
  local cache_file="${CACHE_DIR}/${cache_key}.json"

  # Ensure cache directory exists
  mkdir -p "$CACHE_DIR"

  echo "$data" > "$cache_file"
  return 0
}

# Delete cache entry
# Usage: cache_invalidate <cache_key>
# Returns: Nothing
# Exit code: Always 0
cache_invalidate() {
  local cache_key="$1"
  local cache_file="${CACHE_DIR}/${cache_key}.json"

  rm -f "$cache_file"
  return 0
}

# Check if cache entry exists
# Usage: cache_exists <cache_key>
# Returns: Nothing
# Exit code: 0 if exists, 1 if not
cache_exists() {
  local cache_key="$1"
  local cache_file="${CACHE_DIR}/${cache_key}.json"

  [ -f "$cache_file" ]
}

# Get cache file path for a key
# Usage: cache_path <cache_key>
# Returns: Full path to cache file
cache_path() {
  local cache_key="$1"
  echo "${CACHE_DIR}/${cache_key}.json"
}

# Get cached data or fetch using callback function
# Usage: cache_get_or_fetch <cache_key> <fetch_function> [args...]
# Example: cache_get_or_fetch "jira-PROJ-123" fetch_jira_issue "PROJ-123"
# Returns: Cached data if valid, or freshly fetched data
# Exit code: 0 on success, 1 on fetch failure
cache_get_or_fetch() {
  local cache_key="$1"
  local fetch_function="$2"
  shift 2
  local fetch_args=("$@")

  local cache_file="${CACHE_DIR}/${cache_key}.json"

  # Check if cache exists and is valid
  if [ -f "$cache_file" ]; then
    cat "$cache_file"
    return 0
  fi

  # Cache miss - fetch data
  local data
  if data=$("$fetch_function" "${fetch_args[@]}"); then
    # Save to cache
    cache_set "$cache_key" "$data"
    echo "$data"
    return 0
  else
    return 1
  fi
}

# Check if cache is older than specified time
# Usage: cache_is_stale <cache_key> <max_age_seconds>
# Returns: Nothing
# Exit code: 0 if stale (older than max_age), 1 if fresh
cache_is_stale() {
  local cache_key="$1"
  local max_age="$2"
  local cache_file="${CACHE_DIR}/${cache_key}.json"

  if [ ! -f "$cache_file" ]; then
    return 0  # No cache = stale
  fi

  # Get file modification time
  local file_mtime
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    file_mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo "0")
  else
    # Linux
    file_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || echo "0")
  fi

  local current_time
  current_time=$(date +%s)

  local age=$((current_time - file_mtime))

  [ "$age" -gt "$max_age" ]
}

# Get cached data with time-based expiry
# Usage: cache_get_with_expiry <cache_key> <max_age_seconds> <fetch_function> [args...]
# Example: cache_get_with_expiry "jira-PROJ-123" 300 fetch_jira_issue "PROJ-123"
# Returns: Cached data if fresh, or freshly fetched data
# Exit code: 0 on success, 1 on fetch failure
cache_get_with_expiry() {
  local cache_key="$1"
  local max_age="$2"
  local fetch_function="$3"
  shift 3
  local fetch_args=("$@")

  # Check if cache is stale
  if cache_is_stale "$cache_key" "$max_age"; then
    # Stale or missing - fetch fresh data
    local data
    if data=$("$fetch_function" "${fetch_args[@]}"); then
      cache_set "$cache_key" "$data"
      echo "$data"
      return 0
    else
      return 1
    fi
  else
    # Fresh cache - return it
    cache_get "$cache_key"
    return 0
  fi
}

# Clear all cache files matching a pattern
# Usage: cache_clear_pattern <pattern>
# Example: cache_clear_pattern "jira-*"
# Returns: Number of files deleted
cache_clear_pattern() {
  local pattern="$1"
  local count=0

  if [ -d "$CACHE_DIR" ]; then
    count=$(find "$CACHE_DIR" -name "${pattern}.json" -type f -delete -print | wc -l | tr -d ' ')
  fi

  echo "$count"
  return 0
}

# Get cache statistics
# Usage: cache_stats
# Returns: Multi-line statistics about cache
cache_stats() {
  if [ ! -d "$CACHE_DIR" ]; then
    echo "Cache directory does not exist"
    return 1
  fi

  local total_files
  total_files=$(find "$CACHE_DIR" -type f -name "*.json" | wc -l | tr -d ' ')

  local jira_files
  jira_files=$(find "$CACHE_DIR" -type f -name "jira-*.json" | wc -l | tr -d ' ')

  local confluence_files
  confluence_files=$(find "$CACHE_DIR" -type f -name "confluence-*.json" | wc -l | tr -d ' ')

  local cache_size
  cache_size=$(du -sh "$CACHE_DIR" 2>/dev/null | awk '{print $1}')

  echo "Cache Statistics:"
  echo "  Directory: $CACHE_DIR"
  echo "  Total files: $total_files"
  echo "  Jira files: $jira_files"
  echo "  Confluence files: $confluence_files"
  echo "  Total size: $cache_size"
}

# Build standard cache key for Jira issue
# Usage: cache_key_jira <issue_key>
# Returns: Cache key string
cache_key_jira() {
  local issue_key="$1"
  echo "jira-${issue_key}"
}

# Build standard cache key for Confluence page
# Usage: cache_key_confluence <page_id>
# Returns: Cache key string
cache_key_confluence() {
  local page_id="$1"
  echo "confluence-${page_id}"
}

# Build cache key for Jira search results
# Usage: cache_key_jira_search <query_or_hash>
# Returns: Cache key string
cache_key_jira_search() {
  local query="$1"
  # Create a simple hash of the query
  local hash
  hash=$(echo "$query" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-50)
  echo "jira-search-${hash}"
}

# Build cache key for time-based queries (my updates, etc.)
# Usage: cache_key_time_query <prefix> <days>
# Example: cache_key_time_query "jira-my-updates" 5
# Returns: Cache key string
cache_key_time_query() {
  local prefix="$1"
  local days="$2"
  echo "${prefix}-${days}days"
}
