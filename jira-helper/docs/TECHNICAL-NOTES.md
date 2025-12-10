# Technical Notes and Gotchas

Internal reference for jira-helper implementation details, known issues, and workarounds.

## Confluence Storage Format

### Wiki Markup Representation

**Current implementation:** `representation: "wiki"`

Confluence API accepts multiple storage formats:
- `storage` - XHTML-based storage format
- `wiki` - Legacy wiki markup
- `view` - Read-only rendered HTML

**Why wiki markup:**
- Simpler conversion from markdown
- Direct mapping: `h1.`, `||`, `*`, `{{code}}`
- Less brittle than XHTML generation

**Potential gotcha:**
Confluence's API behavior with `representation: "wiki"` can vary by:
- Instance version (Cloud vs Server vs Data Center)
- Space configuration
- Page template settings

If wiki markup stops rendering properly, alternatives:
1. Switch to `representation: "storage"` with XHTML
2. Implement full wiki-to-storage converter
3. Make representation configurable per-instance

**Current code location:**
- Shared helper: `lib/jira-comment-helpers.sh:_build_confluence_json()`
- Used by: `create_confluence_page()`, `replace_confluence_page()`

**Test if broken:**
```bash
source ~/.jira-helper/jira-helper.sh
echo "# Test\n\n|| A || B ||\n| 1 | 2 |" > /tmp/test.md
create_confluence_page "SPACE" "Test Page" /tmp/test.md
# Check if table renders or shows as raw markup
```

### Newline Preservation

**Pattern:** `printf '%s' "$content" | jq -Rs`

The `-Rs` flags:
- `-R` - Read raw input (don't parse as JSON)
- `-s` - Slurp entire input as single string

This preserves actual newlines instead of escaping them as `\n` literals.

**Why this matters:**
Wiki markup requires specific characters at line starts:
- `h1.` must be at start of line
- `||` for table headers at start of line
- `*` for lists at start of line

If newlines are escaped as `\n`, Confluence sees one long string and doesn't parse markup.

**Alternative approaches tested:**
1. `--arg` - Escapes newlines ❌
2. `--rawfile` - Adds trailing newline ❌
3. `printf + jq -Rs` - Preserves exact content ✓

## Markdown Detection

**Function:** `lib/markdown-to-html.sh:_is_markdown()`

**Logic order matters:**
1. Check markdown markers FIRST
2. Check HTML tags SECOND
3. Default to markdown if ambiguous

**Why order matters:**
Content may contain placeholder text like `<TAB>`, `<your-repo>`, `<value>` that matches HTML regex but isn't actual HTML.

**Pattern:**
```bash
# Markdown markers (priority 1)
if echo "$content" | grep -qE '^#{1,6} |^[-*] |\*\*|__|\[.*\]\(|^\|.*\|'; then
  return 0  # Is markdown
fi

# HTML tags (priority 2) - only match actual elements
if echo "$content" | grep -qE '<(p|div|table|tr|td|th|ul|ol|li|h[1-6]|pre|code|span|strong|em|a)[> ]'; then
  return 1  # Is HTML
fi

# Ambiguous - default markdown
return 0
```

## Shared Helper Pattern

**Problem:** Duplicate logic in `create_confluence_page` and `replace_confluence_page`

**Solution:** Shared helper in `lib/jira-comment-helpers.sh:_build_confluence_json()`

**Benefits:**
- Single source of truth for JSON generation
- Consistent representation handling
- One place to fix when Confluence breaks

**Usage:**
```bash
# Create operation
_build_confluence_json "$content" "$title" "" "$space_key" "$parent_id"

# Update operation
_build_confluence_json "$new_content" "$title" "$((version + 1))"
```

Parameters:
1. `content` - Wiki markup string
2. `title` - Page title
3. `version` - Empty for create, number for update
4. `space_key` - Only for create
5. `parent_id` - Optional, only for create with parent

## Cross-Platform Tool Detection

**Pattern:** Prefer GNU tools, fallback to BSD

```bash
AWK="${GAWK:-${AWK:-awk}}"
SED="${GSED:-${SED:-sed}}"
GREP="${GGREP:-${GREP:-grep}}"
DATE="${GDATE:-${DATE:-date}}"
FIND="${GFIND:-${FIND:-find}}"
```

**Why:**
- GNU tools have consistent regex syntax
- BSD tools (macOS default) have quirks
- Auto-detection via `command -v`

**Install GNU tools on macOS:**
```bash
brew install coreutils grep gnu-sed gawk findutils
```

## Cache Invalidation Strategy

**TTL-based caches:**
- 5 min: EOD reports, personal metrics
- 30 min: Pain points
- 1 hour: Standard metrics
- 6 hours: Age metrics

**Timestamp-based caches:**
- Individual issues: `jira-<key>.timestamp`
- Confluence pages: `confluence-<id>.timestamp`
- Invalidated when remote resource newer

**Manual flush:**
```bash
rm -rf ~/.jira-helper/.atlassian-cache/*
```

## Test Coverage Requirements

**Pattern:** Test both success and failure paths

```bash
# Test [X/Y] - Description
TEST_RESULT="..."
if [ "$TEST_RESULT" = "expected" ]; then
  echo "✓ Test [X/Y] passed"
else
  echo "✗ Test [X/Y] failed"
  exit 1
fi
```

**Current coverage:** 72 tests
- Syntax validation
- Dependency checks
- Function existence
- Integration scenarios

## Known Limitations

1. **No OAuth support** - API tokens only
2. **No attachment upload** - Comments/pages only
3. **No bulk operations** - One issue at a time
4. **No custom fields** - Standard fields only
5. **Confluence tables** - Basic formatting only (no colspan/rowspan)

## Future-Proofing

If Confluence API changes break wiki markup:

1. Add feature flag: `CONFLUENCE_USE_STORAGE=true`
2. Implement XHTML converter in new lib file
3. Update `_build_confluence_json` to check flag
4. Document migration in CLAUDE.md

Keep representation logic centralized in shared helper for easy updates.
