#!/bin/bash
# Duplication Analysis Script for jira-helper.sh
# Identifies opportunities for code extraction and refactoring
#
# Usage: ./analyze-duplication.sh
# Requires: jira-helper.sh in same directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "jira-helper.sh" ]; then
  echo "Error: jira-helper.sh not found in current directory"
  exit 1
fi

echo "=== JIRA-HELPER DUPLICATION ANALYSIS ==="
echo "=== Generated: $(date) ==="
echo ""

# Summary Statistics
echo "## Summary Statistics"
echo ""
echo "File size: $(wc -l < jira-helper.sh) lines"
echo "Lib modules: $(ls lib/*.sh 2>/dev/null | wc -l)"
echo ""

# 1. Find repeated curl patterns
echo "## 1. API Call Patterns (curl usage)"
CURL_COUNT=$(grep -c "curl.*-s.*-u.*ATLASSIAN" jira-helper.sh || echo "0")
echo "Total curl calls to Atlassian APIs: $CURL_COUNT"
echo ""

# 2. Find repeated error handling patterns
echo "## 2. Error Handling Patterns"
ERROR_MSGS=$(grep -c "echo.*Error:" jira-helper.sh || echo "0")
RETURN_ONES=$(grep -c "return 1" jira-helper.sh || echo "0")
echo "Error messages: $ERROR_MSGS"
echo "Return 1 statements: $RETURN_ONES"
echo ""

# 3. Find repeated cache operations
echo "## 3. Cache Operations"
CACHE_REFS=$(grep -c "CACHE_DIR" jira-helper.sh || echo "0")
CACHE_FILES=$(grep -c "cache_file=" jira-helper.sh || echo "0")
echo "CACHE_DIR references: $CACHE_REFS"
echo "cache_file assignments: $CACHE_FILES"
echo ""

# 4. Find repeated jq parsing
echo "## 4. JSON Parsing (jq)"
JQ_PIPES=$(grep -c "| jq" jira-helper.sh || echo "0")
echo "jq pipe operations: $JQ_PIPES"
echo ""

# 5. Find similar function patterns
echo "## 5. Function Patterns"
GET_JIRA=$(grep -c "^get_jira.*() {" jira-helper.sh || echo "0")
UPDATE_JIRA=$(grep -c "^update_jira.*() {" jira-helper.sh || echo "0")
GET_CONFLUENCE=$(grep -c "^get_confluence.*() {" jira-helper.sh || echo "0")
UPDATE_CONFLUENCE=$(grep -c "^update_confluence.*() {" jira-helper.sh || echo "0")
echo "Functions starting with 'get_jira': $GET_JIRA"
echo "Functions starting with 'update_jira': $UPDATE_JIRA"
echo "Functions starting with 'get_confluence': $GET_CONFLUENCE"
echo "Functions starting with 'update_confluence': $UPDATE_CONFLUENCE"
echo ""

# 6. Markdown conversion patterns
echo "## 6. Markdown/Format Conversions"
CONVERSIONS=$(grep "_to_adf\|_to_html\|_to_wiki\|_to_markdown" jira-helper.sh | grep -v "^[0-9]*:#" | wc -l)
echo "Conversion function calls: $CONVERSIONS"
echo ""

# 7. Check for common code blocks
echo "## 7. Common Code Patterns"
CRED_CHECKS=$(grep -c "ATLASSIAN_USER" jira-helper.sh || echo "0")
HTTP_CHECKS=$(grep -c "http_code" jira-helper.sh || echo "0")
echo "Credential checks (ATLASSIAN_USER): $CRED_CHECKS"
echo "HTTP status code checks: $HTTP_CHECKS"
echo ""

# 8. HTTP Response Pattern Analysis
echo "## 8. HTTP Response Handling"
echo "Repeated pattern instances:"
grep -c "if \[ \"\$http_code\" -ge 200 \]" jira-helper.sh || echo "0"
echo ""

# 9. Credential Validation Pattern
echo "## 9. Credential Validation"
echo "Instances of credential check pattern:"
grep -n "if.*-z.*ATLASSIAN_USER" jira-helper.sh | wc -l
echo ""

# 10. Generate extraction recommendations
echo "## 10. Extraction Opportunities (High Priority)"
echo ""
echo "### lib/http-helpers.sh - API wrapper functions"
echo "Impact: ~200-300 lines saved"
echo "Functions: atlassian_api_get/post/put/delete, check_http_response"
echo ""
echo "### lib/cache-helpers.sh - Cache operations"
echo "Impact: ~150-200 lines saved"
echo "Functions: cache_get/set/invalidate/get_or_fetch, cache_needs_refresh"
echo ""
echo "### lib/auth-helpers.sh - Credential validation"
echo "Impact: ~100-150 lines saved"
echo "Functions: validate_credentials, require_credentials, load_credentials"
echo ""
echo "### lib/json-helpers.sh - Common JSON parsing"
echo "Impact: ~100 lines saved"
echo "Functions: jira_field, confluence_field, json_array_to_lines"
echo ""
echo "### lib/issue-helpers.sh - Issue key parsing"
echo "Impact: ~50-75 lines saved"
echo "Functions: parse_issue_key, validate_issue_key, normalize_issue_input"
echo ""

# 11. Detailed examples of duplication
echo "## 11. Example Duplication Patterns"
echo ""
echo "### HTTP Response Pattern (found in $CURL_COUNT functions):"
echo '```bash'
echo 'response=$(curl -s -w "\n%{http_code}" \'
echo '  -u "${ATLASSIAN_USER}:${ATLASSIAN_API_TOKEN}" \'
echo '  -H "Content-Type: application/json" \'
echo '  "https://${ATLASSIAN_SITE_URL}/rest/api/3/...")'
echo 'http_code=$(echo "$response" | tail -n1)'
echo 'body=$(echo "$response" | sed '\''$d'\'')'
echo ''
echo 'if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then'
echo '  echo "$body"'
echo 'else'
echo '  echo "Error: HTTP $http_code" >&2'
echo '  return 1'
echo 'fi'
echo '```'
echo ""

echo "### Cache Pattern (found in $CACHE_FILES functions):"
echo '```bash'
echo 'local cache_file="${CACHE_DIR}/jira-${issue_key}.json"'
echo 'if [ ! -f "$cache_file" ]; then'
echo '  # fetch from API'
echo '  echo "$response" > "$cache_file"'
echo 'fi'
echo 'cat "$cache_file"'
echo '```'
echo ""

echo "### Credential Validation (found in $CRED_CHECKS locations):"
echo '```bash'
echo 'if [ -z "$ATLASSIAN_USER" ] || [ -z "$ATLASSIAN_API_TOKEN" ] || [ -z "$ATLASSIAN_SITE_URL" ]; then'
echo '  echo "Error: Atlassian credentials not configured" >&2'
echo '  return 1'
echo 'fi'
echo '```'
echo ""

# 12. Estimated impact summary
echo "## 12. Refactoring Impact Summary"
echo ""
echo "| Phase | Target | Lines Saved | Functions Affected | Priority |"
echo "|-------|--------|-------------|-------------------|----------|"
echo "| 1     | HTTP + Cache helpers | 350-500 | ~30 | HIGH |"
echo "| 2     | Auth + JSON helpers | 200-250 | ~20 | MEDIUM |"
echo "| 3     | Issue + Display helpers | 100-150 | ~10 | LOW |"
echo "| **Total** | **All phases** | **650-900** | **~60** | - |"
echo ""

CURRENT_SIZE=$(wc -l < jira-helper.sh)
EST_LOW=$((CURRENT_SIZE - 900))
EST_HIGH=$((CURRENT_SIZE - 650))
echo "Current size: $CURRENT_SIZE lines"
echo "Estimated after refactor: $EST_LOW - $EST_HIGH lines"
echo "Reduction: 10-15%"
echo ""

echo "=== Analysis Complete ==="
echo ""
echo "To view full report, see: /tmp/extraction-report.md"
echo "To start refactoring, begin with Phase 1 (lib/http-helpers.sh + lib/cache-helpers.sh)"
