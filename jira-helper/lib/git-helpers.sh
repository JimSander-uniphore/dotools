#!/usr/bin/env bash
# git-helpers.sh - Git history analysis helper functions
#
# This module provides functions for analyzing git history to find
# code owners and suggest reviewers.

# Calculate time-weighted score for a commit
# Usage: calculate_commit_score <days_ago> [half_life_days]
# Returns: Score between 0 and 1
calculate_commit_score() {
  local days_ago="$1"
  local half_life="${2:-182}"  # Default 6 months

  # Exponential decay: score = 2^(-days_ago/half_life)
  # Using awk for floating point math
  awk -v days="$days_ago" -v half="$half_life" 'BEGIN {
    print 2^(-days/half)
  }'
}

# Get commits for a file with time-weighted scores
# Usage: get_file_commits <file_path> [days_back]
# Returns: author_email commit_count total_score (tab-separated)
get_file_commits() {
  local file_path="$1"
  local days_back="${2:-90}"

  if [ ! -f "$file_path" ]; then
    return 1
  fi

  local repo_dir=$(dirname "$file_path")
  cd "$repo_dir" || return 1

  # Get commits with author email and date
  git log --since="${days_back} days ago" --format="%ae|%cr" -- "$(basename "$file_path")" | \
  while IFS='|' read -r email date_str; do
    # Extract days ago from relative date
    local days_ago=$(echo "$date_str" | grep -oE '[0-9]+' | head -1)
    [ -z "$days_ago" ] && days_ago=0

    local score=$(calculate_commit_score "$days_ago")
    echo "$email|$score"
  done
}

# Aggregate commit scores by author
# Usage: aggregate_scores <commit_data>
# Input format: email|score (one per line)
# Returns: email commits total_score (tab-separated, sorted by score desc)
aggregate_scores() {
  awk -F'|' '{
    email[$1]++;
    score[$1]+=$2;
  } END {
    for (e in email) {
      printf "%s\t%d\t%.2f\n", e, email[e], score[e]
    }
  }' | sort -t$'\t' -k3 -rn
}

# Check if GitHub user is active
# Usage: is_github_user_active <username>
# Returns: "active", "suspended", or "unknown"
is_github_user_active() {
  local username="$1"

  if [ -z "$username" ]; then
    echo "unknown"
    return
  fi

  # Check if gh CLI is available
  if ! command -v gh &> /dev/null; then
    echo "unknown"
    return
  fi

  local user_info=$(gh api "users/$username" 2>/dev/null)

  if [ $? -ne 0 ] || [ -z "$user_info" ]; then
    echo "unknown"
    return
  fi

  local suspended=$(echo "$user_info" | jq -r '.suspended_at // empty')

  if [ -n "$suspended" ]; then
    echo "suspended"
  else
    echo "active"
  fi
}

# Extract GitHub username from git email
# Usage: email_to_github_username <email>
# Returns: GitHub username or empty string
email_to_github_username() {
  local email="$1"

  # Remove @uniphore.com, @gmail.com, etc
  local username=$(echo "$email" | sed -E 's/@.*//' | tr '.' '-')

  # Try to verify with gh CLI if available
  if command -v gh &> /dev/null; then
    if gh api "users/$username" &>/dev/null; then
      echo "$username"
      return
    fi

    # Try with "uni-" prefix (common pattern)
    if gh api "users/uni-$username" &>/dev/null; then
      echo "uni-$username"
      return
    fi
  fi

  # Return best guess
  echo "$username"
}

# Find recent contributors to files matching a pattern
# Usage: find_contributors_by_pattern <repo_path> <file_pattern> [days_back]
# Returns: List of contributor emails with commit counts
find_contributors_by_pattern() {
  local repo_path="$1"
  local pattern="$2"
  local days_back="${3:-90}"

  if [ ! -d "$repo_path/.git" ]; then
    echo "Error: Not a git repository: $repo_path" >&2
    return 1
  fi

  cd "$repo_path" || return 1

  # Find files matching pattern
  local files=$(find . -type f -path "*$pattern*" 2>/dev/null)

  if [ -z "$files" ]; then
    return 1
  fi

  # Get commits for all matching files
  echo "$files" | while read -r file; do
    git log --since="${days_back} days ago" --format="%ae" -- "$file"
  done | sort | uniq -c | sort -rn
}

# Get most active contributors in a date range
# Usage: get_active_contributors <repo_path> <since_date> [until_date]
# Returns: email commits_count (sorted by count desc)
get_active_contributors() {
  local repo_path="$1"
  local since_date="$2"
  local until_date="${3:-now}"

  if [ ! -d "$repo_path/.git" ]; then
    echo "Error: Not a git repository: $repo_path" >&2
    return 1
  fi

  cd "$repo_path" || return 1

  git log --since="$since_date" --until="$until_date" --format="%ae" | \
    sort | uniq -c | sort -rn | awk '{print $2"\t"$1}'
}

# Format contributor table for markdown
# Usage: format_contributor_table <contributor_data>
# Input format: name email commits score status (tab-separated)
# Returns: Markdown table
format_contributor_table() {
  cat <<'EOF'
| Name | Email | Commits | Score | GitHub Status |
|------|-------|---------|-------|---------------|
EOF

  while IFS=$'\t' read -r name email commits score status; do
    printf "| %s | %s | %d | %.2f | %s |\n" "$name" "$email" "$commits" "$score" "$status"
  done
}
