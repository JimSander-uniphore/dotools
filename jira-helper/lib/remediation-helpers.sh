#!/usr/bin/env bash
# remediation-helpers.sh - Helper functions for APPCLD ticket remediation
#
# This module provides reusable functions used by the remediate() function
# to analyze security issues and generate remediation documentation.

# Detect if a ticket is about RBAC/secrets access issues
# Usage: is_rbac_issue <description_text>
# Returns: 0 if RBAC issue, 1 otherwise
is_rbac_issue() {
  local description="$1"

  # Match specific patterns that indicate RBAC permission problems
  # NOT just any mention of RBAC (which could be in recommendations)
  echo "$description" | grep -qi "clusterrole.*secret\|serviceaccount.*read.*secret\|secret.*permission.*get\|read all secret\|unauthorized access.*secret"
}

# Detect if a ticket is about Consul unauthenticated access
# Usage: is_consul_issue <description_text>
# Returns: 0 if Consul issue, 1 otherwise
is_consul_issue() {
  local description="$1"

  echo "$description" | grep -qi "consul.*unauthenticated\|consul.*authentication\|consul.*acl"
}

# Detect if a ticket is about outdated Elasticsearch/Kibana
# Usage: is_elasticsearch_issue <description_text>
# Returns: 0 if Elasticsearch issue, 1 otherwise
is_elasticsearch_issue() {
  local description="$1"

  echo "$description" | grep -qi "elasticsearch\|kibana"
}

# Find related files in flux repos for a given cluster
# Usage: find_flux_files <cluster_name>
# Returns: Newline-separated list of related file paths
find_flux_files() {
  local cluster="$1"
  local flux_repo="$HOME/repos/platform-flux"

  if [ ! -d "$flux_repo" ]; then
    echo "Error: platform-flux repo not found at $flux_repo" >&2
    return 1
  fi

  # Find cluster-specific files
  find "$flux_repo/clusters/$cluster" -type f -name "*.yaml" 2>/dev/null | head -5
}

# Extract cluster name from various formats
# Usage: extract_cluster_name <text>
# Returns: cluster name (e.g., uniphore-prod-me1c2g-gke)
extract_cluster_name() {
  local text="$1"

  # Look for uniphore cluster pattern
  echo "$text" | grep -oE 'uniphore-[a-z0-9-]+-(gke|eks|ack)' | head -1
}

# Extract IP addresses from text
# Usage: extract_ips <text>
# Returns: Newline-separated list of IPs
extract_ips() {
  local text="$1"

  echo "$text" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u
}

# Extract ports from text
# Usage: extract_ports <text>
# Returns: Newline-separated list of ports
extract_ports() {
  local text="$1"

  # Look for port patterns like "8500", "5601/tcp", "port 8500"
  echo "$text" | grep -oE '(port[: ]+)?[0-9]{2,5}(/tcp|/udp)?' | grep -oE '[0-9]{2,5}' | sort -u
}

# Format GitHub file link
# Usage: github_file_link <repo> <branch> <file_path>
# Returns: Markdown link to GitHub file
github_file_link() {
  local repo="$1"
  local branch="${2:-main}"
  local file_path="$3"

  local base_name=$(basename "$file_path")
  echo "[\\`${file_path}\\`](https://github.com/uniphore/${repo}/blob/${branch}/${file_path})"
}

# Get priority level from VAPT description
# Usage: get_vapt_priority <description>
# Returns: P0, P1, P2, etc.
get_vapt_priority() {
  local description="$1"

  # Look for explicit priority mentions
  if echo "$description" | grep -qi "critical\|high.*priority\|immediate"; then
    echo "High"
  elif echo "$description" | grep -qi "medium.*priority\|moderate"; then
    echo "Medium"
  elif echo "$description" | grep -qi "low.*priority\|minor"; then
    echo "Low"
  else
    echo "Medium"  # Default
  fi
}

# Check if string contains deployment/release name
# Usage: has_deployment_name <text> <name>
# Returns: 0 if found, 1 otherwise
has_deployment_name() {
  local text="$1"
  local name="$2"

  echo "$text" | grep -qi "$name"
}

# Extract namespace from kubectl output or description
# Usage: extract_namespace <text>
# Returns: namespace name
extract_namespace() {
  local text="$1"

  # Look for "namespace: <name>" or "-n <name>" patterns
  echo "$text" | grep -oE '(namespace:|Namespace:|-n\s+)[a-z0-9-]+' | head -1 | awk '{print $NF}'
}

# Format date for markdown docs
# Usage: format_doc_date [date_string]
# Returns: Formatted date (YYYY-MM-DD)
format_doc_date() {
  local date_str="${1:-now}"

  date -j -f "%Y-%m-%d" "$date_str" "+%Y-%m-%d" 2>/dev/null || date "+%Y-%m-%d"
}

# Create markdown frontmatter
# Usage: create_frontmatter <title> <priority> <status>
# Returns: Markdown frontmatter block
create_frontmatter() {
  local title="$1"
  local priority="$2"
  local status="$3"

  cat <<EOF
# ${title}

| Field | Value |
|-------|-------|
| **Priority** | ${priority} |
| **Status** | ${status} |

EOF
}
