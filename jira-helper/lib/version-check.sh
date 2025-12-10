#!/usr/bin/env bash
# version-check.sh - Version checking and upgrade notifications
#
# This module provides non-nagging version check functionality.
# Checks GitHub releases API once per week maximum.

# Check for newer version and notify if available
# Called lazily on jira-helper commands
# Uses cache to avoid checking more than once per week
_check_version_update() {
  local version_check_file="${JIRA_HELPER_DIR}/.version-check"
  local check_interval=$((7 * 24 * 60 * 60))  # 7 days in seconds
  local current_time
  current_time=$(date +%s)

  # Create version check file if it doesn't exist
  if [ ! -f "$version_check_file" ]; then
    echo "0" > "$version_check_file"
  fi

  # Read last check time
  local last_check
  last_check=$(cat "$version_check_file" 2>/dev/null || echo "0")

  # Check if enough time has passed since last check
  local time_diff=$((current_time - last_check))
  if [ "$time_diff" -lt "$check_interval" ]; then
    # Too soon, skip check
    return 0
  fi

  # Update last check time
  echo "$current_time" > "$version_check_file"

  # Check GitHub releases API for latest version
  # Use jira-helper repo location from git remote
  local github_repo=""
  if git -C "$JIRA_HELPER_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    local git_remote
    git_remote=$(git -C "$JIRA_HELPER_DIR" remote get-url origin 2>/dev/null || echo "")

    if [[ "$git_remote" =~ github.com ]]; then
      # Extract org/repo from git remote URL
      # git@github.com:org/repo.git → org/repo
      # https://github.com/org/repo.git → org/repo
      github_repo=$(echo "$git_remote" | "$SED" -E '
        s|^git@github\.com:||
        s|^https://github\.com/||
        s|\.git$||
      ')
    fi
  fi

  if [ -z "$github_repo" ]; then
    # No GitHub repo detected, skip check
    return 0
  fi

  # Check for latest version using git tags (works for both public and private repos)
  # This requires the repo to be cloned and up to date
  local latest_version
  latest_version=$(git -C "$JIRA_HELPER_DIR" fetch --tags 2>/dev/null && \
    git -C "$JIRA_HELPER_DIR" tag -l 2>/dev/null | \
    grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+" | \
    sort -V | \
    tail -1)

  if [ -z "$latest_version" ]; then
    # No version tags found, skip notification
    return 0
  fi

  # Compare versions (strip 'v' prefix if present)
  local current_version="${JIRA_HELPER_VERSION#v}"
  latest_version="${latest_version#v}"

  if [ "$latest_version" != "$current_version" ]; then
    # Newer version available
    echo "" >&2
    echo "╔═════════════════════════════════════════════════════════════╗" >&2
    echo "║  jira-helper update available: ${latest_version} (current: ${current_version})  ║" >&2
    echo "║                                                             ║" >&2
    echo "║  To update, run:                                            ║" >&2
    echo "║    cd ${JIRA_HELPER_DIR}" >&2
    echo "║    ./install.sh                                             ║" >&2
    echo "║                                                             ║" >&2
    echo "║  (install.sh will pull latest changes automatically)       ║" >&2
    echo "║  (Checked weekly, next check in 7 days)                    ║" >&2
    echo "╚═════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
  fi

  return 0
}

# Manual version check command
# Usage: jira-helper version check
check_version() {
  echo "Current version: ${JIRA_HELPER_VERSION}"
  echo "Checking for updates..."

  # Check GitHub releases API
  local github_repo=""
  if git -C "$JIRA_HELPER_DIR" rev-parse --git-dir > /dev/null 2>&1; then
    local git_remote
    git_remote=$(git -C "$JIRA_HELPER_DIR" remote get-url origin 2>/dev/null || echo "")

    if [[ "$git_remote" =~ github.com ]]; then
      github_repo=$(echo "$git_remote" | "$SED" -E '
        s|^git@github\.com:||
        s|^https://github\.com/||
        s|\.git$||
      ')
    fi
  fi

  if [ -z "$github_repo" ]; then
    echo "Error: Not a GitHub repository or no remote configured"
    return 1
  fi

  echo "Checking for updates..."

  # Check latest version using git tags (works for both public and private repos)
  local latest_version
  latest_version=$(git -C "$JIRA_HELPER_DIR" fetch --tags 2>/dev/null && \
    git -C "$JIRA_HELPER_DIR" tag -l 2>/dev/null | \
    grep -E "^v?[0-9]+\.[0-9]+\.[0-9]+" | \
    sort -V | \
    tail -1)

  if [ -z "$latest_version" ]; then
    echo "Error: No version tags found in repository"
    return 1
  fi

  echo "Latest version: ${latest_version}"

  local current_version="${JIRA_HELPER_VERSION#v}"
  local latest_clean="${latest_version#v}"

  if [ "$latest_clean" = "$current_version" ]; then
    echo "✓ You're up to date!"
  else
    echo ""
    echo "Update available!"
    echo ""
    echo "To update, run:"
    echo "  cd ${JIRA_HELPER_DIR}"
    echo "  ./install.sh"
    echo ""
    echo "(install.sh will pull latest changes automatically)"
  fi

  return 0
}
