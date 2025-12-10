#!/usr/bin/env bash
# Voluntary stats sharing for jira-helper 4-week pilot
# Users run this to contribute anonymized usage data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE_LOG="${SCRIPT_DIR}/.usage-log"

if [ ! -f "$USAGE_LOG" ]; then
  echo "No usage data found at: $USAGE_LOG"
  echo ""
  echo "Either tracking is not enabled, or you haven't used jira-helper yet."
  echo ""
  echo "Enable tracking: export JIRA_HELPER_TRACK_USAGE=true"
  exit 0
fi

echo "=== Jira Helper Pilot - Share Your Stats ==="
echo ""
echo "This will share anonymized usage data to help improve jira-helper."
echo ""
echo "Preview of what will be shared:"
echo "----------------------------------------"

# Source jira-helper to use jira_helper_stats function
source "${SCRIPT_DIR}/jira-helper.sh"
JIRA_HELPER_QUIET=true  # Suppress loading messages

# Show stats
jira_helper_stats

echo "----------------------------------------"
echo ""
echo "Your identity will be anonymized (first 8 chars of username hash)."
echo "NO ticket numbers, NO content, NO credentials are included."
echo ""

read -p "Share this data? (y/N): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Stats not shared. No problem!"
  echo ""
  echo "If you change your mind, run: ./share-stats.sh"
  exit 0
fi

# Generate anonymous ID (first 8 chars of username hash)
ANON_ID=$(echo "$USER" | md5sum 2>/dev/null | cut -d' ' -f1 | cut -c1-8 || echo "$USER" | md5 | cut -c1-8)

echo "Your anonymous ID: ${ANON_ID}"
echo ""

# Method 1: Save to file for manual sharing
OUTPUT_FILE="${SCRIPT_DIR}/my-stats-${ANON_ID}.txt"
{
  echo "Jira Helper Usage Stats"
  echo "Anonymous ID: ${ANON_ID}"
  echo "Submission Date: $(date +%Y-%m-%d)"
  echo ""
  jira_helper_stats
  echo ""
  echo "--- Raw Log (last 50 entries) ---"
  tail -50 "$USAGE_LOG"
} > "$OUTPUT_FILE"

echo "✓ Stats saved to: $OUTPUT_FILE"
echo ""
echo "Share options:"
echo ""
echo "1. Email to pilot coordinator:"
echo "   mail -s 'Jira Helper Stats' jim@company.com < \"$OUTPUT_FILE\""
echo ""
echo "2. Slack/Teams: Attach the file to a message"
echo ""
echo "3. Shared drive:"
echo "   cp \"$OUTPUT_FILE\" /path/to/shared/jira-helper-pilot/"
echo ""
echo "Thank you for helping improve jira-helper!"
