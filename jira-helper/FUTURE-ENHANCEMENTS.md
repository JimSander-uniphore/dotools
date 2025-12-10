# Future Enhancements

Tracking ideas and improvements for jira-helper beyond v1.0.

## Confluence Markdown Sync

### Option 5: Separate Workflows (v1.0 - Implemented)
- `jh doc push markdowns/api.md` - Create NEW Confluence page from markdown (one-time)
- `jh doc pull PAGE-ID` - Pull Confluence → markdown (read-only)
- No auto-sync, explicit operations only
- Current implementation: `set_confluence_source` / `get_confluence_source` track mappings only

### Option 4: One-way Push with Conflict Detection (Future)
**Goal**: Smart markdown → Confluence sync with safety checks

**Workflow**:
1. User edits local `.md` file
2. Run `jh doc sync markdowns/api.md` or `jh doc push markdowns/api.md --check-conflicts`
3. Before push: Check if Confluence page modified since last sync
4. If modified: Show diff and prompt
   ```
   Confluence page was modified 2 hours ago by jane@company.com

   Changes in Confluence:
   + Added section on error handling
   + Updated API endpoint URLs

   Your local changes:
   + Added authentication examples
   + Fixed typos in introduction

   Options:
   1) Overwrite Confluence (lose their changes)
   2) Pull their changes first (lose your local changes)
   3) Show full diff for manual merge
   4) Cancel
   ```
5. User decides case-by-case

**Implementation notes**:
- Track last sync timestamp in source mapping cache
- Use Confluence page version API to detect changes
- Require explicit `--force` flag to overwrite without prompt
- Log all sync operations for audit trail

**Safety guardrails**:
- Never auto-sync without user confirmation
- Warn if page has multiple recent editors
- Show diff summary before any destructive operation
- Maintain sync history in cache

## Histogram Improvements

Current state: Functional but not publication-ready (noted in README)

**Improvements needed**:
- Better ASCII art rendering for age/priority distributions
- Clearer bucket labels and ranges
- Option to output as CSV/JSON for external graphing
- Color coding in terminal output (if supported)
- Percentile markers (p50, p75, p95)

## Enhanced Metrics

- **Velocity tracking**: Story points completed over time
- **Cycle time analysis**: Time in each status
- **SLA monitoring**: Time to first response, time to resolution
- **Team collaboration**: Co-assignee patterns, handoff frequency
- **Label analytics**: Most common labels, label combinations

## Search Improvements

- **Full-text search**: Search across issue descriptions and comments (not just summary)
- **Advanced JQL builder**: Interactive query construction with validation
- **Saved searches**: Store frequently used JQL queries with aliases
- **Search history**: Recent searches with quick re-run

## Workflow Automation

- **Bulk operations**: Update multiple tickets at once
- **Issue templates**: Pre-defined ticket structures for common scenarios
- **Auto-linking**: Detect and link related tickets based on patterns
- **Status automation**: Auto-transition based on conditions

## Integration Enhancements

- **Git integration**: Link commits to Jira tickets, show ticket info in git log
- **Slack webhooks**: Post updates to Slack channels
- **Email summaries**: Scheduled EOD reports via email
- **CI/CD integration**: Update tickets from pipeline events

## Performance Optimizations

- **Parallel API calls**: Fetch multiple resources concurrently
- **Smart cache warming**: Pre-fetch likely needed data
- **Compression**: Compress large cache files
- **Incremental updates**: Fetch only changes since last sync

## User Experience

- **Interactive mode**: TUI for browsing issues (like `tig` for git)
- **Fuzzy search**: Find tickets without exact key (search by summary keywords)
- **Keyboard shortcuts**: Quick actions without typing full commands
- **Config profiles**: Switch between different Atlassian instances

## Claude Code Extension Integration Issues (HIGH PRIORITY)

**Problem**: Claude Code extension fails to use jira-helper functions correctly due to shell snapshot isolation.

**Observed Errors**:
```bash
line 649: _log: command not found
line 635: /confluence-4220125196.timestamp: Read-only file system
cat: /confluence-4220125196.json: No such file or directory
```

**Root Causes**:
1. **Shell Snapshot Isolation**: Claude uses isolated shell snapshots (`~/.claude/shell-snapshots/snapshot-bash-*.sh`) that don't inherit:
   - Environment variables from user's shell profile
   - Functions sourced from `jira-helper.sh`
   - Proper `$CACHE_DIR` variable (defaults to empty string → `/filename` paths)

2. **Missing Function Definitions**: The `_log()` helper function isn't available in the snapshot context

3. **Environment Not Bootstrapped**: When Claude runs bash commands, it doesn't automatically source `$JIRA_HELPER_PATH`

**Solutions Needed**:

### Short-term (v1.0.1 - Critical Bug Fix):
1. **Make functions defensive**:
   ```bash
   # Instead of:
   _log "message"

   # Use:
   [ "${JIRA_HELPER_QUIET:-false}" != "true" ] && echo "message" >&2

   # Or define fallback:
   type _log >/dev/null 2>&1 || _log() { echo "$@" >&2; }
   ```

2. **Validate CACHE_DIR before use**:
   ```bash
   if [ -z "$CACHE_DIR" ]; then
     echo "Error: CACHE_DIR not set. Source jira-helper.sh first:" >&2
     echo "  source ~/.jira-helper/jira-helper.sh" >&2
     return 1
   fi
   ```

3. **Auto-bootstrap in Claude context**:
   ```bash
   # At top of jira-helper.sh, detect Claude environment
   if [ -n "$CLAUDECODE" ] || [ -n "$CLAUDE_CODE_SESSION" ]; then
     # Re-export critical vars even if already sourced
     export CACHE_DIR="${CACHE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.atlassian-cache}"
     export JIRA_HELPER_PATH="${JIRA_HELPER_PATH:-${BASH_SOURCE[0]}}"
   fi
   ```

### Medium-term (v1.1 - Better Claude Integration):
1. **Update .claude/config instructions** to include explicit sourcing:
   ```markdown
   - Before calling jira-helper functions, ALWAYS run:
     source "$JIRA_HELPER_PATH" 2>/dev/null || source ~/.jira-helper/jira-helper.sh
   - Example Bash tool usage:
     source ~/.jira-helper/jira-helper.sh && get_confluence_page 4220125196
   ```

2. **Wrapper script** for Claude-safe execution:
   ```bash
   # ~/.jira-helper/jira-helper-wrapper.sh
   #!/bin/bash
   source ~/.jira-helper/jira-helper.sh
   "$@"
   ```
   Then Claude config suggests: `jira-helper-wrapper.sh get_confluence_page 4220125196`

3. **Better error messages** when environment missing:
   ```bash
   if [ -z "$ATLASSIAN_USER" ]; then
     cat >&2 <<EOF
   Error: jira-helper environment not initialized

   Quick fix:
     source ~/.jira-helper/jira-helper.sh

   Or for Claude Code, ensure .claude/config has:
     ## Atlassian policy
     export JIRA_HELPER_PATH="~/.jira-helper/jira-helper.sh"
     - ALWAYS source jira-helper.sh using: source "\$JIRA_HELPER_PATH"

   Run: jira-helper help
   EOF
     return 1
   fi
   ```

### Long-term (v2.0 - Robust Architecture):
1. **Standalone executable mode**: Compile to single binary or use shebang script that self-initializes
2. **State file**: Store environment in `~/.jira-helper/env` that functions can source independently
3. **Claude MCP alternative**: Provide thin MCP wrapper that calls jira-helper functions correctly
4. **Integration tests**: Test in Claude Code environment specifically

**Priority**: HIGH - This blocks the primary use case ("Give Claude direct access to your Jira/Confluence")

**Acceptance Criteria**:
- [x] Claude Code can successfully call `get_confluence_page 4220125196` (FIXED: Updated .claude/config with explicit sourcing pattern)
- [x] Wrapper installed to ~/.jira-helper/jira-helper (FIXED: install.sh now copies wrapper)
- [ ] Claude Code can add Jira comments without errors
- [ ] Error messages guide users to correct the environment
- [ ] Documentation includes Claude Code troubleshooting section

**Status: PARTIALLY RESOLVED** - Core issue fixed by updating .claude/config and install.sh. Remaining work is improved error messages.

## Code Reorganization (v2.0)

**Goal**: Restructure monolithic script into modular, maintainable architecture

**Current Issues**:
- Single 4,814-line file makes navigation and maintenance difficult
- No clear module boundaries between Jira, Confluence, metrics, utilities
- Testing individual components is challenging
- Mixed concerns (dev artifacts, cache, source code in same directory)

**Proposed Structure**:
```
jira-helper/
├── bin/
│   └── jira-helper              # Main entry point (thin wrapper)
├── lib/
│   ├── core/
│   │   ├── init.sh             # Initialization, credentials
│   │   ├── cache.sh            # Cache management
│   │   └── utils.sh            # Common utilities, logging
│   ├── jira/
│   │   ├── issues.sh           # Issue operations
│   │   ├── comments.sh         # Comment operations
│   │   ├── search.sh           # Search functions
│   │   └── transitions.sh      # Workflow transitions
│   ├── confluence/
│   │   ├── pages.sh            # Page operations
│   │   └── search.sh           # Confluence search
│   ├── reporting/
│   │   ├── eod.sh              # End-of-day reports
│   │   └── metrics.sh          # Metrics functions
│   └── adf/
│       ├── converter.sh        # Markdown to ADF conversion
│       └── formatters.sh       # ADF formatting helpers
├── completions/
│   └── jira-helper.bash        # Bash completion
├── tests/
│   ├── unit/                   # Unit tests per module
│   ├── integration/            # Integration tests
│   └── fixtures/               # Test data
├── docs/                       # All documentation
├── scripts/                    # Install, setup scripts
└── templates/                  # Existing templates
```

**Benefits**:
- Functions grouped by domain for easier location and modification
- Clear module boundaries enable isolated testing
- Cleaner development environment (test artifacts separated)
- Better IDE navigation and search
- Easier onboarding for contributors
- Single cache location (no dev vs installed confusion)

**Migration Strategy**:
1. Phase 1: Extract modules (no breaking changes, main script sources modules)
2. Phase 2: Update installer to copy lib/ structure
3. Phase 3: Move tests, docs to proper directories
4. Phase 4: Add CI/CD automation

**Priority**: Low - Current structure works, this is a quality-of-life improvement

**Acceptance Criteria**:
- All existing functionality works unchanged
- Installation process updated for new structure
- Tests verify module loading works correctly
- Documentation updated with new file locations

## Documentation

- **Video tutorials**: Screen recordings for common workflows
- **Best practices guide**: Recommended patterns for different team sizes
- **Migration guide**: Moving from other Jira CLI tools
- **API reference**: Complete function documentation with examples

## Testing & Quality

- **Integration tests**: Test against real Atlassian APIs (sandbox)
- **Performance benchmarks**: Track speed improvements over time
- **Error recovery**: Better handling of network failures and API errors
- **Validation**: Check JQL syntax before sending to API

## Security & Compliance

- **Audit logging**: Track all operations for compliance
- **Multi-user support**: Team shared cache with access controls
- **SSO integration**: Support for enterprise auth methods
- **Data retention**: Auto-cleanup of old cache data

---

## Contributing Ideas

Have an enhancement idea? Add it to this file or open an issue in the repo.

**Format**:
```markdown
## Your Enhancement Category

**Goal**: Brief description

**Workflow**: Step-by-step usage

**Implementation notes**: Technical considerations

**Priority**: Low / Medium / High
```
