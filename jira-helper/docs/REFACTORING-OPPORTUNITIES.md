# Jira-Helper Duplication Analysis & Extraction Opportunities

## Executive Summary
- **Current size**: 6,126 lines in jira-helper.sh
- **41 curl calls** to Atlassian APIs
- **49 HTTP status code checks** with similar patterns
- **17 cache file operations** with repeated logic
- **58 credential validation checks**

## High-Priority Extraction Candidates

### 1. HTTP API Helper (lib/http-helpers.sh) - **HIGH IMPACT**
**Duplication**: 41 curl calls, 49 HTTP status checks

**Common Pattern**:
```bash
response=$(curl -s -w "\n%{http_code}" \
  -u "${ATLASSIAN_USER}:${ATLASSIAN_API_TOKEN}" \
  -H "Content-Type: application/json" \
  "https://${ATLASSIAN_SITE_URL}/rest/api/3/...")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
  echo "$body"
else
  echo "Error: HTTP $http_code" >&2
  return 1
fi
```

**Proposed Functions**:
- `atlassian_api_get()` - GET requests with auth
- `atlassian_api_post()` - POST requests with JSON body
- `atlassian_api_put()` - PUT requests  
- `atlassian_api_delete()` - DELETE requests
- `check_http_response()` - Validate status codes

**Impact**: Would eliminate ~200-300 lines of duplicate code

---

### 2. Cache Helper (lib/cache-helpers.sh) - **HIGH IMPACT**
**Duplication**: 17 cache file operations, 69 CACHE_DIR references

**Common Patterns**:
```bash
# Pattern 1: Get with cache
local cache_file="${CACHE_DIR}/jira-${issue_key}.json"
if [ ! -f "$cache_file" ]; then
  # fetch from API
  echo "$response" > "$cache_file"
fi
cat "$cache_file"

# Pattern 2: Cache invalidation check
if needs_jira_refresh "$issue_key"; then
  # refetch
fi
```

**Proposed Functions**:
- `cache_get()` - Get cached data or return empty
- `cache_set()` - Write to cache
- `cache_get_or_fetch()` - Get cached or fetch with callback
- `cache_invalidate()` - Remove cache entry
- `cache_needs_refresh()` - Check if cache is stale

**Impact**: Would eliminate ~150-200 lines

---

### 3. Credential Validator (lib/auth-helpers.sh) - **MEDIUM IMPACT**
**Duplication**: 58 credential checks

**Common Pattern**:
```bash
if [ -z "$ATLASSIAN_USER" ] || [ -z "$ATLASSIAN_API_TOKEN" ] || [ -z "$ATLASSIAN_SITE_URL" ]; then
  echo "Error: Atlassian credentials not configured" >&2
  echo "Please set up ~/.jira file with credentials" >&2
  return 1
fi
```

**Proposed Functions**:
- `validate_credentials()` - Check all required vars
- `require_credentials()` - Validate and exit on failure
- `load_credentials()` - Source ~/.jira with validation

**Impact**: Would eliminate ~100-150 lines

---

### 4. JSON Parser Helpers (lib/json-helpers.sh) - **MEDIUM IMPACT**  
**Duplication**: 87 jq operations with similar patterns

**Common Patterns**:
```bash
# Extract standard Jira fields
jq -r '.fields.summary'
jq -r '.fields.status.name'
jq -r '.fields.assignee.displayName // "Unassigned"'
jq -r '.fields.updated'

# Extract Confluence fields
jq -r '.title'
jq -r '.version.number'
jq -r '.body.storage.value'
```

**Proposed Functions**:
- `jira_field()` - Extract Jira field with fallback
- `confluence_field()` - Extract Confluence field
- `json_array_to_lines()` - Convert JSON array to lines
- `json_exists()` - Check if path exists

**Impact**: Would eliminate ~100 lines

---

### 5. Issue Key Parser (lib/issue-helpers.sh) - **LOW-MEDIUM IMPACT**
**Duplication**: Multiple places extract/validate issue keys

**Common Patterns**:
```bash
# Extract from URL
issue_key=$(echo "$input" | grep -oE '[A-Z]+-[0-9]+')

# Extract from various formats
[[ "$input" =~ ^[A-Z]+-[0-9]+$ ]]
```

**Proposed Functions**:
- `parse_issue_key()` - Extract from URL or text
- `validate_issue_key()` - Check format
- `normalize_issue_input()` - Handle URL, key, or browse link

**Impact**: Would eliminate ~50-75 lines

---

## Lower Priority Opportunities

### 6. URL Builders (Already partially in http-helpers)
- `jira_api_url()` - Build Jira REST URLs
- `confluence_api_url()` - Build Confluence REST URLs

### 7. Display Formatters (lib/display-helpers.sh)
- `format_issue_summary()` - Format issue for display
- `format_table_row()` - Format data as table
- `colorize_status()` - Add ANSI colors for statuses

### 8. Date/Time Helpers (lib/time-helpers.sh)  
- `relative_time()` - "2 hours ago" formatting
- `iso_to_local()` - Convert ISO timestamps
- `days_ago()` - Calculate date N days ago

---

## Refactoring Priority

**Phase 1** (Highest ROI):
1. lib/http-helpers.sh - API wrapper functions
2. lib/cache-helpers.sh - Cache operations

**Phase 2** (Medium ROI):
3. lib/auth-helpers.sh - Credential validation
4. lib/json-helpers.sh - Common JSON parsing

**Phase 3** (Polish):
5. lib/issue-helpers.sh - Issue key parsing
6. Additional formatters and utilities

---

## Estimated Impact

| Refactor | Lines Saved | Functions Simplified | Maintainability |
|----------|-------------|---------------------|-----------------|
| Phase 1  | 350-500     | ~30 functions       | +++             |
| Phase 2  | 200-250     | ~20 functions       | ++              |
| Phase 3  | 100-150     | ~10 functions       | +               |
| **Total**| **650-900** | **~60 functions**   | **Very High**   |

**Result**: jira-helper.sh could shrink from 6,126 lines to ~5,200-5,500 lines while being more maintainable.

