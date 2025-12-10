# jira-helper Function Coverage Analysis

**Generated:** 2025-11-11

## Summary

| Metric | Count | Status |
|--------|-------|--------|
| Total functions in code | 53 | ✓ |
| Public functions | 47 | ✓ |
| Private functions (_*) | 6 | ✓ |
| Functions tested in run-tests.sh | 47 | ✓ COMPLETE |
| Functions documented in README.md | 7 | ⚠️ INCOMPLETE |
| Functions in help output | 47 | ✓ COMPLETE |

## Source of Truth Hierarchy

1. **jira-helper.sh** (code) - DEFINITIVE SOURCE
2. **jira_helper help** (output) - Auto-generated from code
3. **run-tests.sh** - NOW COMPLETE (tests all 47 public functions)
4. **README.md** - INCOMPLETE (only 7 documented)

## Three-Way Dependency Status

### ✓ jira-helper.sh → run-tests.sh
**Status:** COMPLETE
- run-tests.sh now tests all 47 public functions
- Auto-fails if any public function is missing

### ✓ jira-helper.sh → jira_helper help
**Status:** IN SYNC
- Help output manually maintained but complete
- Covers all major functions with examples

### ⚠️ jira-helper.sh → README.md
**Status:** INCOMPLETE
- README only documents 7 functions in detail
- Missing 40 functions from documentation

## Missing from README.md (40 functions)

### Workspace Management (5)
- cleanup_workspaces
- discover_workspaces
- list_workspaces
- workspace_stats
- jira_helper_info

### Jira Operations (11)
- create_jira_ticket (mentioned in examples but not in function list)
- create_jira_subtask
- fetch_jira_issue
- get_jira_transitions
- get_last_comment_id
- get_priority_id
- get_user_account_id
- needs_jira_refresh
- open_jira_issue
- parse_jira_key
- search_newly_assigned_issues

### Confluence Operations (8)
- create_confluence_page
- fetch_confluence_page
- get_confluence_page (mentioned but not detailed)
- list_confluence_sources (mentioned)
- needs_confluence_refresh
- open_confluence_page
- replace_confluence_page
- update_confluence_page

### Metrics (7)
- jira_metrics_age
- jira_metrics_churn
- jira_metrics_creation
- jira_metrics_painpoints
- jira_metrics_personal
- jira_metrics_priority
- jira_metrics_volume (only this one mentioned)

### Utilities (9)
- is_cache_fresh
- jira_helper
- jira_helper_cmd
- remediate (mentioned but not documented)
- self_update
- set_confluence_source (mentioned)
- get_confluence_source (mentioned)
- search_my_confluence_updates
- search_my_jira_updates (mentioned)
- suggest_reviewers (mentioned but not documented)

## Recommendation

**Option 1: Keep README concise** (current approach)
- Document only the most common 10-15 functions
- Point to `jira_helper help` for complete reference
- Pros: Easier to maintain, less overwhelming
- Cons: Users may miss features

**Option 2: Complete README documentation**
- Document all 47 functions with examples
- Organize by category (like help output)
- Pros: Single source for users, SEO friendly
- Cons: Large file, harder to maintain sync

**Option 3: Hybrid approach** (RECOMMENDED)
- README: Document top 15-20 functions with examples
- Add new section: "See `jira_helper help` for 30+ more functions"
- Create separate FUNCTIONS.md with complete reference
- Pros: Best of both worlds
- Cons: One more file to maintain

## Action Items

1. ✅ DONE: Update run-tests.sh to test all 47 public functions
2. ⚠️ TODO: Decide on README documentation strategy
3. ⚠️ TODO: Add missing high-value functions to README:
   - search_newly_assigned_issues (very useful!)
   - All 7 metrics functions
   - create_jira_subtask
   - Workspace management functions

