#!/usr/bin/env bash
# Automated test runner for jira-helper
# Usage: ./run-tests.sh [--quick]
#   --quick: Run fast syntax/function checks without API calls (for CI/PR checks)
#   (no flag): Run full integration tests with real API calls

# Don't exit on errors - we want to run all tests and report results
set +e

# Parse arguments
QUICK_MODE=false
if [[ "$1" == "--quick" ]]; then
  QUICK_MODE=true
fi

# Determine script directory (where run-tests.sh lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Setup test directory - use temp dir or existing ~/testHelper
if [ -d "$HOME/testHelper/jira-helper" ]; then
  # CI or pre-existing setup
  TEST_DIR="$HOME/testHelper"
  JIRA_HELPER_DIR="${TEST_DIR}/jira-helper"
else
  # Local development - create temp directory and copy files
  TEST_DIR=$(mktemp -d -t jira-helper-tests-XXXXXX)
  JIRA_HELPER_DIR="${TEST_DIR}/jira-helper"

  echo "Setting up test environment in: $TEST_DIR"
  mkdir -p "$JIRA_HELPER_DIR"

  # Copy all files from script directory to test directory
  cp -r "$SCRIPT_DIR"/* "$JIRA_HELPER_DIR/"

  # Ensure scripts are executable
  chmod +x "$JIRA_HELPER_DIR"/*.sh 2>/dev/null || true

  echo "Test environment ready"
  echo ""
fi

RESULTS_FILE="${TEST_DIR}/test-results.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test result tracking
PASSED=0
FAILED=0
SKIPPED=0

log_test() {
  local test_name="$1"
  echo ""
  echo "========================================" | tee -a "$RESULTS_FILE"
  echo "TEST: $test_name" | tee -a "$RESULTS_FILE"
  echo "========================================" | tee -a "$RESULTS_FILE"
}

log_pass() {
  local message="$1"
  echo -e "${GREEN}✓ PASS${NC}: $message" | tee -a "$RESULTS_FILE"
  ((PASSED++))
}

log_fail() {
  local message="$1"
  echo -e "${RED}✗ FAIL${NC}: $message" | tee -a "$RESULTS_FILE"
  ((FAILED++))
}

log_skip() {
  local message="$1"
  echo -e "${YELLOW}⊘ SKIP${NC}: $message" | tee -a "$RESULTS_FILE"
  ((SKIPPED++))
}

# Initialize results file
echo "jira-helper Test Results - $(date)" > "$RESULTS_FILE"
echo "=======================================" >> "$RESULTS_FILE"
if [ "$QUICK_MODE" = true ]; then
  echo "MODE: Quick (syntax/function checks only)" >> "$RESULTS_FILE"
else
  echo "MODE: Full (integration tests with API calls)" >> "$RESULTS_FILE"
fi
echo "=======================================" >> "$RESULTS_FILE"

# Check prerequisites
log_test "Prerequisites Check"

# Check for GNU tools
echo "Checking for GNU tools..." | tee -a "$RESULTS_FILE"
HAS_GAWK=false
HAS_GSED=false

if command -v gawk >/dev/null 2>&1; then
  HAS_GAWK=true
  log_pass "gawk found: $(command -v gawk)"
elif command -v awk >/dev/null 2>&1; then
  # Test if BSD awk has required features
  if echo "test" | awk '/^```/{print "ok"}' >/dev/null 2>&1; then
    HAS_GAWK=true
    log_pass "awk found (sufficient for basic operations): $(command -v awk)"
  else
    log_fail "awk found but lacks GNU features (fenced code blocks will fail)"
  fi
else
  log_fail "No awk/gawk found"
fi

if command -v gsed >/dev/null 2>&1; then
  HAS_GSED=true
  log_pass "gsed found: $(command -v gsed)"
elif command -v sed >/dev/null 2>&1; then
  # Test if BSD sed has extended regex support
  if echo "test" | sed -E 's/test/ok/' 2>/dev/null | grep -q "ok"; then
    HAS_GSED=true
    log_pass "sed found with -E support: $(command -v sed)"
  else
    log_fail "sed found but lacks extended regex support"
  fi
else
  log_fail "No sed/gsed found"
fi

# Test GNU-specific awk features (multiline state tracking)
if [ "$HAS_GAWK" = true ]; then
  TEST_OUTPUT=$(cat <<'EOF' | $(command -v gawk || command -v awk) '
BEGIN { in_code = 0 }
/^```/ {
  if (in_code == 0) {
    in_code = 1
    printf "<pre><code>"
  } else {
    printf "</code></pre>\n"
    in_code = 0
  }
  next
}
in_code == 1 { print; next }
{ print }
'
### Test
```
# Code
```
End
EOF
)
  if echo "$TEST_OUTPUT" | grep -q "<pre><code>"; then
    log_pass "awk supports fenced code block parsing"
  else
    log_fail "awk does not support fenced code block parsing correctly"
  fi
fi

# Test GNU-specific sed features (extended regex)
if [ "$HAS_GSED" = true ]; then
  SED_CMD=$(command -v gsed || command -v sed)
  TEST_OUTPUT=$(echo "**bold** and *italic*" | "$SED_CMD" -E 's/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g')
  if echo "$TEST_OUTPUT" | grep -q "<strong>bold</strong>"; then
    log_pass "sed supports extended regex for markdown conversion"
  else
    log_fail "sed does not support required regex patterns"
  fi
fi

if [ "$QUICK_MODE" = false ]; then
  # Full mode requires credentials
  if [ ! -f "$HOME/.jira" ]; then
    echo ""
    echo "Missing ~/.jira credentials file"
    echo ""
    echo "Would you like to set up credentials now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      cd "$JIRA_HELPER_DIR" || exit 1
      ./setup-credentials.sh
      if [ -f "$HOME/.jira" ]; then
        log_pass "Credentials set up successfully"
      else
        log_fail "Failed to set up credentials"
        exit 1
      fi
    else
      log_fail "Cannot proceed without credentials"
      echo "To set up later, run: cd $JIRA_HELPER_DIR && ./setup-credentials.sh"
      exit 1
    fi
  else
    log_pass "Found ~/.jira credentials"
  fi
else
  # Quick mode - skip credentials check
  if [ -f "$HOME/.jira" ]; then
    log_pass "Found ~/.jira credentials"
  else
    log_skip "Skipping credentials check in quick mode"
  fi
fi

if [ ! -d "$JIRA_HELPER_DIR" ]; then
  log_fail "Missing jira-helper directory at $JIRA_HELPER_DIR"
  exit 1
else
  log_pass "Found jira-helper directory"
fi

# Test 1: Source jira-helper.sh
log_test "1. Source jira-helper.sh"

cd "$JIRA_HELPER_DIR" || exit 1

# Source directly (not in subshell) and capture output to temp file
TEMP_OUTPUT=$(mktemp)
source ./jira-helper.sh > "$TEMP_OUTPUT" 2>&1

if grep -q "Bash completion loaded" "$TEMP_OUTPUT"; then
  log_pass "jira-helper.sh sourced successfully"
else
  log_fail "Failed to source jira-helper.sh"
  cat "$TEMP_OUTPUT" >> "$RESULTS_FILE"
fi
rm -f "$TEMP_OUTPUT"

# Test 2: Source without credentials (emulate user experience)
log_test "2. Source jira-helper.sh without credentials"

# Temporarily hide ~/.jira if it exists
JIRA_CREDS_BACKUP=""
if [ -f "$HOME/.jira" ]; then
  JIRA_CREDS_BACKUP="$HOME/.jira.test-backup"
  mv "$HOME/.jira" "$JIRA_CREDS_BACKUP"
fi

# Source in a subshell to avoid polluting current environment
TEMP_OUTPUT=$(mktemp)
(
  cd "$JIRA_HELPER_DIR" || exit 1
  source ./jira-helper.sh > "$TEMP_OUTPUT" 2>&1
  EXIT_CODE=$?
  exit $EXIT_CODE
)
SOURCE_EXIT_CODE=$?

# Restore ~/.jira if it was backed up
if [ -n "$JIRA_CREDS_BACKUP" ] && [ -f "$JIRA_CREDS_BACKUP" ]; then
  mv "$JIRA_CREDS_BACKUP" "$HOME/.jira"
fi

# Check that sourcing succeeded without exiting
if [ $SOURCE_EXIT_CODE -eq 0 ]; then
  if grep -q "Bash completion loaded" "$TEMP_OUTPUT"; then
    log_pass "jira-helper.sh sourced successfully without credentials"
  else
    log_fail "jira-helper.sh did not load completion without credentials"
    cat "$TEMP_OUTPUT" >> "$RESULTS_FILE"
  fi
else
  log_fail "jira-helper.sh exited with code $SOURCE_EXIT_CODE when sourced without credentials"
  cat "$TEMP_OUTPUT" >> "$RESULTS_FILE"
fi
rm -f "$TEMP_OUTPUT"

# Change back to the test directory after sourcing (jira-helper may change cwd)
cd "$JIRA_HELPER_DIR" || exit 1

# Check critical variables
if [ -n "$CACHE_DIR" ]; then
  log_pass "CACHE_DIR set to: $CACHE_DIR"
else
  log_fail "CACHE_DIR not set"
fi

if [ -n "$JIRA_HELPER_REGISTRY" ]; then
  log_pass "JIRA_HELPER_REGISTRY set to: $JIRA_HELPER_REGISTRY"
else
  log_fail "JIRA_HELPER_REGISTRY not set"
fi

# Test 1.5: Version consistency check
log_test "1.5. Version Consistency"

# Check that JIRA_HELPER_VERSION variable matches all hardcoded references
VERSION_ERRORS=0

# Check install.sh QUICKREF template
if grep -q "VERSION: ${JIRA_HELPER_VERSION}" ./install.sh; then
  log_pass "install.sh QUICKREF version matches: ${JIRA_HELPER_VERSION}"
else
  FOUND_VERSION=$(grep "^VERSION:" ./install.sh | head -1 | awk '{print $2}')
  log_fail "install.sh QUICKREF version mismatch: found ${FOUND_VERSION}, expected ${JIRA_HELPER_VERSION}"
  ((VERSION_ERRORS++))
fi

# Check JIRA_HELPER_GITHUB_REF default references JIRA_HELPER_VERSION variable
if grep -q 'JIRA_HELPER_GITHUB_REF=.*\${JIRA_HELPER_VERSION}' ./jira-helper.sh; then
  log_pass "JIRA_HELPER_GITHUB_REF uses JIRA_HELPER_VERSION variable"
else
  FOUND_REF=$(grep "^JIRA_HELPER_GITHUB_REF=" ./jira-helper.sh | head -1)
  log_fail "JIRA_HELPER_GITHUB_REF should reference \${JIRA_HELPER_VERSION} variable, found: ${FOUND_REF}"
  ((VERSION_ERRORS++))
fi

# Verify no other hardcoded version strings exist (semver with optional -rcN suffix)
# Exclude: line 6 (JIRA_HELPER_VERSION definition), lines with variable references, and comment/help text examples
HARDCODED=$(grep -nE 'v[0-9]+\.[0-9]+\.[0-9]+(-rc[0-9]+)?' ./jira-helper.sh | grep -v "^6:" | grep -v "JIRA_HELPER_GITHUB_REF" | grep -v "JIRA_HELPER_VERSION" | grep -v "^[0-9]*:.*#" | grep -v "Example:")
if [ -n "$HARDCODED" ]; then
  log_fail "Found hardcoded version strings in jira-helper.sh (excluding comments/examples):"
  echo "$HARDCODED" | tee -a "$RESULTS_FILE"
  ((VERSION_ERRORS++))
else
  log_pass "No hardcoded version strings found (all use JIRA_HELPER_VERSION variable)"
fi

if [ $VERSION_ERRORS -eq 0 ]; then
  log_pass "All version references are consistent"
else
  log_fail "Version consistency check failed with $VERSION_ERRORS errors"
fi

# Test 2: Function availability
log_test "2. Core Jira Functions"

declare -a core_jira_functions=(
  "get_jira_issue"
  "show_jira_issue"
  "fetch_jira_issue"
  "needs_jira_refresh"
  "search_my_jira_updates"
  "add_jira_comment"
  "update_jira_comment"
  "create_jira_ticket"
  "create_jira_subtask"
  "update_jira_issue"
  "get_jira_transitions"
  "get_priority_id"
  "get_user_account_id"
)

for func in "${core_jira_functions[@]}"; do
  if type "$func" &>/dev/null; then
    log_pass "Function exists: $func"
  else
    log_fail "Function missing: $func"
  fi
done

# Test 2b: Confluence Functions
log_test "2b. Confluence Functions"

declare -a confluence_functions=(
  "get_confluence_page"
  "fetch_confluence_page"
  "needs_confluence_refresh"
  "search_my_confluence_updates"
  "get_confluence_source"
  "set_confluence_source"
  "list_confluence_sources"
  "update_confluence_page"
  "replace_confluence_page"
)

for func in "${confluence_functions[@]}"; do
  if type "$func" &>/dev/null; then
    log_pass "Function exists: $func"
  else
    log_fail "Function missing: $func"
  fi
done

# Test 2c: Metrics Functions
log_test "2c. Metrics Functions"

declare -a metrics_functions=(
  "jira_metrics_volume"
  "jira_metrics_creation"
  "jira_metrics_age"
  "jira_metrics_priority"
  "jira_metrics_churn"
  "jira_metrics_personal"
  "jira_metrics_painpoints"
)

for func in "${metrics_functions[@]}"; do
  if type "$func" &>/dev/null; then
    log_pass "Function exists: $func"
  else
    log_fail "Function missing: $func"
  fi
done

# Test 2d: Reporting & Workspace Functions
log_test "2d. Reporting & Workspace Functions"

declare -a reporting_functions=(
  "eod_report"
  "jira_helper_info"
  "jira_helper_cmd"
  "self_update"
  "list_workspaces"
  "discover_workspaces"
  "workspace_stats"
  "cleanup_workspaces"
  "jira_helper"
  "jira-helper"
)

for func in "${reporting_functions[@]}"; do
  if type "$func" &>/dev/null; then
    log_pass "Function exists: $func"
  else
    log_fail "Function missing: $func"
  fi
done

# Test 2e: Internal Helper Functions
log_test "2e. Internal Helper Functions"

declare -a internal_functions=(
  "is_cache_fresh"
  "_log"
  "_register_workspace"
  "_jira_helper_completions"
  "_jira_helper_function_completions"
  "parse_jira_key"
  "_get_jira_issue_json"
)

for func in "${internal_functions[@]}"; do
  if type "$func" &>/dev/null; then
    log_pass "Function exists: $func"
  else
    log_fail "Function missing: $func"
  fi
done

# ==============================================================================
# Pre-Integration Setup
# ==============================================================================

# Test 3: Ensure cache directory exists before API tests
log_test "3. Cache Directory Setup"

# Create cache directory if it doesn't exist (needed for API tests)
if [ ! -d "$CACHE_DIR" ]; then
  mkdir -p "$CACHE_DIR"
  if [ -d "$CACHE_DIR" ]; then
    log_pass "Created cache directory: $CACHE_DIR"
  else
    log_fail "Failed to create cache directory: $CACHE_DIR"
  fi
else
  log_pass "Cache directory exists: $CACHE_DIR"
fi

FILE_COUNT=$(find "$CACHE_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
log_pass "Cache contains $FILE_COUNT JSON files"

# ==============================================================================
# Integration Tests
# Quick mode: Minimal scope (1 issue, basic validation)
# Full mode: Comprehensive tests (multiple endpoints, error handling, performance)
# ==============================================================================

if [ "$QUICK_MODE" = true ]; then
  # Quick mode: Test ONE API call with minimal scope to verify basic connectivity
  log_test "4. Minimal API Smoke Test (Quick Mode)"

  if [ ! -f "$HOME/.jira" ]; then
    log_skip "No credentials - skipping API test"
  else
    # Test single issue fetch (minimal scope: 1 API call)
    OUTPUT=$(get_jira_issue PANK-1797 --json 2>&1)
    if echo "$OUTPUT" | grep -q '"key":"PANK-1797"'; then
      log_pass "API connectivity verified (fetched 1 issue)"
    else
      log_fail "API test failed"
      echo "$OUTPUT" | head -10 >> "$RESULTS_FILE"
    fi
  fi

  log_skip "Skipping comprehensive integration tests (--quick mode)"
  log_skip "Run without --quick flag for full API coverage"
else
  # Full mode: Comprehensive integration tests
  # Test 3: get_jira_issue (formatted output by default)
  log_test "3. get_jira_issue PANK-1797 (formatted)"

  OUTPUT=$(get_jira_issue PANK-1797 2>&1)
  if echo "$OUTPUT" | grep -q "Key:.*PANK-1797"; then
    log_pass "Retrieved PANK-1797 successfully (formatted)"
  else
    log_fail "Failed to retrieve PANK-1797"
    echo "$OUTPUT" >> "$RESULTS_FILE"
  fi

  # Test 3b: get_jira_issue with --json flag
  log_test "3b. get_jira_issue PANK-1797 --json"

  OUTPUT=$(get_jira_issue PANK-1797 --json 2>&1)
  if echo "$OUTPUT" | grep -q '"key":"PANK-1797"'; then
    log_pass "Retrieved PANK-1797 successfully (JSON)"
  else
    log_fail "Failed to retrieve PANK-1797 with --json"
    echo "$OUTPUT" >> "$RESULTS_FILE"
  fi

  # Check cache file created
  CACHE_FILE="${CACHE_DIR}/jira-PANK-1797.json"
  if [ -f "$CACHE_FILE" ]; then
    log_pass "Cache file created: $CACHE_FILE"
    SIZE=$(stat -f%z "$CACHE_FILE" 2>/dev/null || stat -c%s "$CACHE_FILE" 2>/dev/null)
    log_pass "Cache file size: $SIZE bytes"
  else
    log_fail "Cache file not created"
  fi

  # Test 4: show_jira_issue (formatted output)
  log_test "4. show_jira_issue PANK-1797"

  OUTPUT=$(show_jira_issue PANK-1797 2>&1)
  if echo "$OUTPUT" | grep -q "PANK-1797"; then
    log_pass "Formatted output contains issue key"
  else
    log_fail "Formatted output missing issue key"
  fi

  if echo "$OUTPUT" | grep -q "Status:"; then
    log_pass "Formatted output contains status"
  else
    log_fail "Formatted output missing status"
  fi

  if echo "$OUTPUT" | grep -q "Priority:"; then
    log_pass "Formatted output contains priority"
  else
    log_fail "Formatted output missing priority"
  fi

  # Test 5: Cache reuse
  log_test "5. Cache Performance"

  # First run - should use cache
  CACHE_TIMESTAMP_BEFORE=$(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE" 2>/dev/null)
  OUTPUT=$(show_jira_issue PANK-1797 2>&1)

  if echo "$OUTPUT" | grep -q "Using cached data"; then
    log_pass "Using cached data (no API call)"
  else
    log_skip "Cache message not shown (may be suppressed)"
  fi

  CACHE_TIMESTAMP_AFTER=$(stat -f%m "$CACHE_FILE" 2>/dev/null || stat -c%Y "$CACHE_FILE" 2>/dev/null)
  if [ "$CACHE_TIMESTAMP_BEFORE" -eq "$CACHE_TIMESTAMP_AFTER" ]; then
    log_pass "Cache file unchanged (no re-fetch)"
  else
    log_fail "Cache file modified (unexpected re-fetch)"
  fi

  # Test 6: eod_report
  log_test "6. eod_report"

  OUTPUT=$(eod_report 1 2>&1)
  if echo "$OUTPUT" | grep -q "JIRA ISSUES UPDATED:"; then
    log_pass "EOD report generated"
  else
    log_fail "EOD report failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 7: jira_metrics_personal
  log_test "7. jira_metrics_personal"

  OUTPUT=$(jira_metrics_personal 2>&1)
  if echo "$OUTPUT" | grep -qE "(Total|In Progress|To Do)"; then
    log_pass "Personal metrics generated"
  else
    log_fail "Personal metrics failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 8: jira_metrics_volume
  log_test "8. jira_metrics_volume 7"

  OUTPUT=$(jira_metrics_volume 7 2>&1)
  if echo "$OUTPUT" | grep -qE "(Created|Closed|Open)"; then
    log_pass "Volume metrics generated"
  else
    log_fail "Volume metrics failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 9: jira_metrics_painpoints
  log_test "9. jira_metrics_painpoints"

  OUTPUT=$(jira_metrics_painpoints 2>&1)
  if echo "$OUTPUT" | grep -qE "(Blocked|Unassigned|Pain Points)"; then
    log_pass "Pain points metrics generated"
  else
    log_fail "Pain points metrics failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 10: Error handling - invalid ticket
  log_test "10. Error Handling - Invalid Ticket"

  OUTPUT=$(get_jira_issue INVALID-99999 2>&1)
  if echo "$OUTPUT" | grep -qE "(404|error|Error|not found)"; then
    log_pass "Invalid ticket handled gracefully with error message"
  else
    log_fail "Invalid ticket error not handled properly"
    echo "$OUTPUT" >> "$RESULTS_FILE"
  fi

  # Test 10b: Additional Metrics Functions
  log_test "10b. jira_metrics_creation"

  OUTPUT=$(jira_metrics_creation 7 2>&1)
  if echo "$OUTPUT" | grep -qE "(Created|Creator|Trend)"; then
    log_pass "Creation metrics generated"
  else
    log_fail "Creation metrics failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 10c: jira_metrics_priority
  log_test "10c. jira_metrics_priority"

  OUTPUT=$(jira_metrics_priority 30 2>&1)
  if echo "$OUTPUT" | grep -qE "(Priority|High|Medium|Low)"; then
    log_pass "Priority metrics generated"
  else
    log_fail "Priority metrics failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 10d: jira_metrics_churn
  log_test "10d. jira_metrics_churn"

  OUTPUT=$(jira_metrics_churn 30 2>&1)
  if echo "$OUTPUT" | grep -qE "(Churn|Reopened)"; then
    log_pass "Churn metrics generated"
  else
    log_fail "Churn metrics failed"
    echo "$OUTPUT" | head -20 >> "$RESULTS_FILE"
  fi

  # Test 10e: EOD Report Format Variations
  log_test "10e. eod_report Format Variations"

  # Test default format
  OUTPUT=$(eod_report 1 2>&1)
  if echo "$OUTPUT" | grep -q "JIRA ISSUES UPDATED:"; then
    log_pass "EOD report (default format) generated"
  else
    log_fail "EOD report (default format) failed"
  fi

  # Test slack format
  OUTPUT=$(eod_report 1 slack 2>&1)
  if [ -n "$OUTPUT" ]; then
    log_pass "EOD report (slack format) generated"
  else
    log_fail "EOD report (slack format) failed"
  fi

  # Test slack_compact format
  OUTPUT=$(eod_report 1 slack_compact 2>&1)
  if [ -n "$OUTPUT" ]; then
    log_pass "EOD report (slack_compact format) generated"
  else
    log_fail "EOD report (slack_compact format) failed"
  fi

  # Test 10f: Confluence Functions
  log_test "10f. Confluence Functions"

  # Test search_my_confluence_updates
  OUTPUT=$(search_my_confluence_updates 1 2>&1)
  if [ -n "$OUTPUT" ] || echo "$OUTPUT" | grep -qE "(page|confluence|No updates)"; then
    log_pass "search_my_confluence_updates executed"
  else
    log_fail "search_my_confluence_updates failed"
    echo "$OUTPUT" | head -10 >> "$RESULTS_FILE"
  fi

  # Test 10g: Search Functions
  log_test "10g. search_my_jira_updates"

  OUTPUT=$(search_my_jira_updates 1 2>&1)
  if [ -n "$OUTPUT" ] || echo "$OUTPUT" | grep -qE "(issue|ticket|No updates)"; then
    log_pass "search_my_jira_updates executed"
  else
    log_fail "search_my_jira_updates failed"
    echo "$OUTPUT" | head -10 >> "$RESULTS_FILE"
  fi

  # Test 10h: Cache Freshness Check
  log_test "10h. is_cache_fresh Function"

  # Create a test cache file
  TEST_CACHE="${CACHE_DIR}/test-cache.json"
  echo '{"test": true}' > "$TEST_CACHE"

  if is_cache_fresh "$TEST_CACHE" 3600; then
    log_pass "is_cache_fresh detects fresh cache (< 1 hour)"
  else
    log_fail "is_cache_fresh failed to detect fresh cache"
  fi

  # Test stale cache (0 second TTL)
  sleep 1
  if ! is_cache_fresh "$TEST_CACHE" 0; then
    log_pass "is_cache_fresh detects stale cache (0 TTL)"
  else
    log_fail "is_cache_fresh failed to detect stale cache"
  fi

  rm -f "$TEST_CACHE"

  # Test 10i: Parameter Variations - jira_metrics_volume
  log_test "10i. jira_metrics_volume Parameter Variations"

  # Test with 1 day
  OUTPUT=$(jira_metrics_volume 1 2>&1)
  if echo "$OUTPUT" | grep -qE "(Created|Closed|Open)"; then
    log_pass "jira_metrics_volume 1 day"
  else
    log_fail "jira_metrics_volume 1 day failed"
  fi

  # Test with 30 days
  OUTPUT=$(jira_metrics_volume 30 2>&1)
  if echo "$OUTPUT" | grep -qE "(Created|Closed|Open)"; then
    log_pass "jira_metrics_volume 30 days"
  else
    log_fail "jira_metrics_volume 30 days failed"
  fi

  # Test with specific project
  OUTPUT=$(jira_metrics_volume 7 PANK 2>&1)
  if echo "$OUTPUT" | grep -qE "(Created|Closed|Open)"; then
    log_pass "jira_metrics_volume with project filter"
  else
    log_fail "jira_metrics_volume with project filter failed"
  fi

  # Test 10j: Error Handling - Missing Parameters
  log_test "10j. Error Handling - Missing Parameters"

  # Test show_jira_issue without parameter
  OUTPUT=$(show_jira_issue 2>&1)
  if echo "$OUTPUT" | grep -qE "(Error|Usage|required)"; then
    log_pass "show_jira_issue without parameter shows usage"
  else
    log_fail "show_jira_issue missing parameter error not handled"
  fi

  # Test 10k: Workspace Functions
  log_test "10k. Workspace Functions"

  # Test list_workspaces
  OUTPUT=$(list_workspaces 2>&1)
  if [ -n "$OUTPUT" ] || echo "$OUTPUT" | grep -qE "(workspace|No workspaces)"; then
    log_pass "list_workspaces executed"
  else
    log_fail "list_workspaces failed"
  fi

  # Test workspace_stats
  OUTPUT=$(workspace_stats 2>&1)
  if [ -n "$OUTPUT" ] || echo "$OUTPUT" | grep -qE "(workspace|stats|No workspaces)"; then
    log_pass "workspace_stats executed"
  else
    log_fail "workspace_stats failed"
  fi
fi

# Test 11: Workspace Registry
log_test "11. Workspace Registry"

if [ -f "$JIRA_HELPER_REGISTRY" ]; then
  log_pass "Registry file exists: $JIRA_HELPER_REGISTRY"

  WORKSPACE_COUNT=$(jq '.workspaces | length' "$JIRA_HELPER_REGISTRY" 2>/dev/null || echo "0")
  log_pass "Registry contains $WORKSPACE_COUNT workspace(s)"
else
  log_skip "Registry file not yet created (created on first registration)"
fi

# Test 12: Priority ID Mapping (PANK-1798)
log_test "12. get_priority_id Function"

PRIORITY_ID=$(get_priority_id "High" 2>&1)
if [ "$PRIORITY_ID" = "2" ]; then
  log_pass "Priority 'High' maps to ID 2"
else
  log_fail "Priority 'High' mapping failed (got: $PRIORITY_ID)"
fi

PRIORITY_ID=$(get_priority_id "Medium" 2>&1)
if [ "$PRIORITY_ID" = "3" ]; then
  log_pass "Priority 'Medium' maps to ID 3"
else
  log_fail "Priority 'Medium' mapping failed (got: $PRIORITY_ID)"
fi

PRIORITY_ID=$(get_priority_id "5" 2>&1)
if [ "$PRIORITY_ID" = "5" ]; then
  log_pass "Numeric priority ID passed through correctly"
else
  log_fail "Numeric priority ID passthrough failed"
fi

# Test 13: New Hierarchical Commands (Option 3)
log_test "13. Hierarchical issue/issues Commands"

# Test 13a: jira_helper issue <key>
OUTPUT=$(jira_helper issue PANK-1797 2>&1)
if echo "$OUTPUT" | grep -q "PANK-1797"; then
  log_pass "jira_helper issue PANK-1797 works"
else
  log_fail "jira_helper issue PANK-1797 failed"
fi

# Test 13b: jira_helper issue <key> --json
OUTPUT=$(jira_helper issue PANK-1797 --json 2>&1)
if echo "$OUTPUT" | jq -e '.key == "PANK-1797"' > /dev/null 2>&1; then
  log_pass "jira_helper issue PANK-1797 --json returns valid JSON"
else
  log_fail "jira_helper issue PANK-1797 --json failed"
fi

# Test 13c: jira_helper issue transitions <key>
OUTPUT=$(jira_helper issue transitions PANK-1797 2>&1)
if echo "$OUTPUT" | grep -qE "(Transition|Available)"; then
  log_pass "jira_helper issue transitions PANK-1797 works"
else
  log_fail "jira_helper issue transitions PANK-1797 failed"
fi

# Test 13d: jira_helper issues (defaults to mine)
OUTPUT=$(jira_helper issues 2>&1)
if echo "$OUTPUT" | grep -qE "(PANK-|No issues found)"; then
  log_pass "jira_helper issues (default) works"
else
  log_fail "jira_helper issues (default) failed"
fi

# Test 13e: jira_helper issues mine
OUTPUT=$(jira_helper issues mine 2>&1)
if echo "$OUTPUT" | grep -qE "(PANK-|No issues found)"; then
  log_pass "jira_helper issues mine works"
else
  log_fail "jira_helper issues mine failed"
fi

# Test 13f: jira_helper issues search 7
OUTPUT=$(jira_helper issues search 7 2>&1)
if echo "$OUTPUT" | grep -qE "(PANK-|No issues found)"; then
  log_pass "jira_helper issues search 7 works"
else
  log_fail "jira_helper issues search 7 failed"
fi

# Test 13g: jira_helper issue without parameter
OUTPUT=$(jira_helper issue 2>&1)
if echo "$OUTPUT" | grep -qE "(Error|Usage)"; then
  log_pass "jira_helper issue without parameter shows error"
else
  log_fail "jira_helper issue missing parameter not handled"
fi

# Test 13h: jira_helper issues with invalid subcommand
OUTPUT=$(jira_helper issues invalid 2>&1)
if echo "$OUTPUT" | grep -qE "(Error|Unknown)"; then
  log_pass "jira_helper issues with invalid subcommand shows error"
else
  log_fail "jira_helper issues invalid subcommand not handled"
fi

# Test 13i: jira_helper issue with invalid ticket key format
OUTPUT=$(jira_helper issue my-next 2>&1)
if echo "$OUTPUT" | grep -qE "(Error|Invalid|format)"; then
  log_pass "jira_helper issue with invalid ticket key shows error"
else
  log_fail "jira_helper issue invalid ticket key not handled"
fi

# Test 14: Markdown Conversion for Confluence
log_test "14. Markdown to HTML Conversion"

if [ -f "$JIRA_HELPER_DIR/markdowns/test-markdown.md" ]; then
  # Test fenced code blocks
  TEST_MD=$(cat <<'EOF'
### Test Header

```
# Code comment (not header)
/.github/ @team
* @default
```

Regular paragraph
EOF
)

  # Simulate the markdown conversion logic from create_confluence_page
  AWK_CMD=$(command -v gawk || command -v awk)
  SED_CMD=$(command -v gsed || command -v sed)

  CONVERTED=$(echo "$TEST_MD" | "$AWK_CMD" '
    BEGIN { in_code = 0 }
    /^```/ {
      if (in_code == 0) {
        in_code = 1
        printf "<pre><code>"
      } else {
        printf "</code></pre>\n"
        in_code = 0
      }
      next
    }
    in_code == 1 {
      gsub(/&/, "\\&amp;")
      gsub(/</, "\\&lt;")
      gsub(/>/, "\\&gt;")
      print
      next
    }
    { print }
  ' | "$SED_CMD" -E '
    s/^# (.*)$/<h1>\1<\/h1>/g
    s/^## (.*)$/<h2>\1<\/h2>/g
    s/^### (.*)$/<h3>\1<\/h3>/g
  ')

  # Validate conversions
  PASS_COUNT=0
  FAIL_COUNT=0

  # Check 1: Code block is wrapped in <pre><code>
  if echo "$CONVERTED" | grep -q "<pre><code>"; then
    log_pass "Fenced code blocks convert to <pre><code>"
    ((PASS_COUNT++))
  else
    log_fail "Fenced code blocks not converting to <pre><code>"
    ((FAIL_COUNT++))
  fi

  # Check 2: # inside code block does NOT become <h1>
  if ! echo "$CONVERTED" | grep -q "<h1>Code comment"; then
    log_pass "Headers inside code blocks are not converted"
    ((PASS_COUNT++))
  else
    log_fail "Headers inside code blocks incorrectly converted"
    echo "$CONVERTED" | grep "Code comment" >> "$RESULTS_FILE"
    ((FAIL_COUNT++))
  fi

  # Check 3: Header outside code block IS converted
  if echo "$CONVERTED" | grep -q "<h3>Test Header</h3>"; then
    log_pass "Headers outside code blocks are converted"
    ((PASS_COUNT++))
  else
    log_fail "Headers outside code blocks not converted"
    ((FAIL_COUNT++))
  fi

  # Check 4: Special characters in code are escaped
  if echo "$CONVERTED" | grep -q "&lt;"; then
    log_pass "Special characters in code blocks are escaped"
    ((PASS_COUNT++))
  else
    log_skip "No special characters to escape in test (expected)"
  fi

  echo "Markdown conversion: $PASS_COUNT passed, $FAIL_COUNT failed" | tee -a "$RESULTS_FILE"
else
  log_skip "markdowns/test-markdown.md not found, skipping markdown conversion tests"
fi

# Summary
echo "" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo "TEST SUMMARY" | tee -a "$RESULTS_FILE"
echo "========================================" | tee -a "$RESULTS_FILE"
echo -e "${GREEN}Passed:  $PASSED${NC}" | tee -a "$RESULTS_FILE"
echo -e "${RED}Failed:  $FAILED${NC}" | tee -a "$RESULTS_FILE"
echo -e "${YELLOW}Skipped: $SKIPPED${NC}" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}ALL TESTS PASSED${NC}" | tee -a "$RESULTS_FILE"
  exit 0
else
  echo -e "${RED}SOME TESTS FAILED${NC}" | tee -a "$RESULTS_FILE"
  echo "Full results in: $RESULTS_FILE"
  exit 1
fi
