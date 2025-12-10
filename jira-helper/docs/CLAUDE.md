# Claude Code Integration Guide

This document explains how Claude Code integrates with jira-helper and provides troubleshooting guidance.

## Quick Start

After running `./install.sh`, Claude Code will be configured with these directives in `~/.claude/config`:

```
## Atlassian policy
export JIRA_HELPER_PATH="/Users/you/.jira-helper/jira-helper.sh"
- CRITICAL: For Jira/Confluence, use jira-helper.sh functions when available.
- ALWAYS source jira-helper.sh BEFORE calling any jira-helper function: source "$JIRA_HELPER_PATH" 2>/dev/null
- Pattern: source ~/.jira-helper/jira-helper.sh && get_confluence_page 4220125196
- NEVER modify ~/.jira (credentials file). Only read from it.
- Do not hand-roll curl for Atlassian if a jira-helper function exists.
- Cache file reads are allowed: Read(/Users/user/.jira-helper/**) and Read(/Users/user/.jira-helper/.atlassian-cache/**)
- Always write API responses to a cache file. Do not pipe curl output directly to jq.
  - Pattern: `curl ... -o cache.json 2>/dev/null`, then `jq ... cache.json`.
- NEVER use MCP Atlassian tools (mcp__atlassian* or mcp__atlassian-official*).
- For Atlassian operations, ONLY use jira-helper.sh functions.

**Function Discovery:**
- Quick reference: Read(/Users/user/.jira-helper/QUICKREF.txt) - READ THIS FIRST for available functions
- Full help: source ~/.jira-helper/jira-helper.sh && jira_helper help
- List functions: declare -F | grep -E 'jira_|confluence_|eod_'

**CRITICAL - Do NOT invent flags:**
- Supported flags: --yes / --force (bypass confirmations), --json (get_jira_issue only)
- Do NOT use unsupported flags like --open, --verbose, etc.
- jira-helper issue TICKET-123 displays the issue and prints the URL - use separate open command to open in browser
- When in doubt, check jira_helper help first
```

## How It Works

### 1. Function Discovery

Claude discovers jira-helper functions dynamically by running `jira_helper help`:

```bash
source ~/.jira-helper/jira-helper.sh && jira_helper help
```

This shows all available commands grouped by category:
- Issue operations (get, search, create, comment, update)
- Confluence operations (get page, search, source mapping)
- Reports (EOD reports with multiple formats)
- Metrics (volume, age, priority, churn, personal, painpoints)

### 2. Usage Pattern

Every jira-helper command follows this pattern:

```bash
source ~/.jira-helper/jira-helper.sh && <function_name> <args>
```

**Examples:**
```bash
# Get Jira issue
source ~/.jira-helper/jira-helper.sh && get_jira_issue PANK-1234

# Get Confluence page
source ~/.jira-helper/jira-helper.sh && get_confluence_page 4220125196

# Generate EOD report
source ~/.jira-helper/jira-helper.sh && eod_report 1 slack

# Add comment to Jira
source ~/.jira-helper/jira-helper.sh && add_jira_comment PANK-1234 "Working on this"
```

### 3. Natural Language Interface

Users don't need to know the syntax. They just ask Claude in natural language:

- "show me PANK-1234"
- "get Confluence page 4220125196"
- "generate my EOD report for yesterday"
- "add a comment to PANK-1234 saying I'm working on this"
- "what are the blocked tickets in PANK?"

Claude translates these to the appropriate jira-helper commands.

## Configuration Details

### Minimal Configuration (Recommended)

The installer adds configuration to `~/.claude/config` as documented in the Quick Start section above.

**What it includes:**
- Function sourcing pattern and safety guardrails
- API response caching requirement (no piping curl to jq)
- MCP tool exclusion (use jira-helper functions only)
- Flag usage restrictions (only --yes, --force, --json)
- Function discovery methods

**Why these directives?**
- Ensures consistent, safe usage patterns
- Prevents common mistakes (piping curl, inventing flags)
- Keeps Claude from using MCP tools when jira-helper is available
- Dynamic function discovery via `jira_helper help`

### Smart Update Logic

The installer intelligently manages your `.claude/config`:

1. **First install** - Adds complete "## Atlassian policy" section
2. **Subsequent installs** - Replaces entire section with latest directives
3. **Preserves other sections** - Only touches "## Atlassian policy" block

**Update behavior:**
```bash
# If section doesn't exist
Adding Atlassian policy configuration to .claude/config...

# If section exists
Updating Atlassian policy configuration in .claude/config...
```

**Section boundaries:**
- Starts with `## Atlassian policy`
- Ends at next `##` heading or end of file
- Everything between is replaced on update

## Available Functions

### Jira Operations

**View Issues:**
- `get_jira_issue TICKET-123 [--json]` - Get issue details (formatted or JSON)
- `show_jira_issue TICKET-123` - Show formatted issue
- `search_my_jira_updates [days]` - Your recent updates
- `search_newly_assigned_issues [days]` - Newly assigned, not yet touched

**Modify Issues:**
- `create_jira_ticket PROJECT "Summary" "Description" "Type"` - Create ticket
- `add_jira_comment TICKET-123 "Comment" [--yes|--force]` - Add comment
- `update_jira_issue TICKET-123 <field> <value> [--yes|--force]` - Update field
- `update_jira_comment TICKET-123 <id> "Text" [--yes|--force]` - Update comment

**Safety Features:**
- Write operations prompt if you're not assignee/reporter/watcher
- Use `--yes` or `--force` to bypass confirmation

### Confluence Operations

- `get_confluence_page PAGE_ID` - Get page content
- `search_my_confluence_updates [days]` - Your recent page updates
- `get_confluence_source PAGE_ID` - Get source file path
- `set_confluence_source PAGE_ID <path>` - Set source mapping
- `list_confluence_sources` - List all source mappings

### Reports

- `eod_report [days] [format]` - End-of-day report
  - Formats: `default`, `slack`, `slack_compact`, `slack_plain`
  - Example: `eod_report 1 slack_compact`

### Metrics

Access via `jira_helper metrics <subcommand>`:

- `volume [days] [project]` - Created/closed/open counts
- `creation [days]` - Top creators and trends
- `age [project] [max_pages]` - Age distribution
- `priority [days] [project]` - Priority health
- `churn [days] [project]` - Reopened tickets
- `personal [email]` - Your workload
- `painpoints [project]` - Blocked and unassigned

## Troubleshooting

### Problem: Claude doesn't know about jira-helper functions

**Symptom:** Claude tries to use `curl` instead of jira-helper functions

**Solution:**
1. Check if `.claude/config` has the Atlassian policy section:
   ```bash
   grep -A 3 "## Atlassian policy" ~/.claude/config
   ```

2. If missing, run installer:
   ```bash
   cd ~/repos/platform-utilities/jira-helper && ./install.sh
   ```

3. Restart Claude Code session

### Problem: Functions not found

**Symptom:** `command not found: get_jira_issue`

**Solution:** Always source jira-helper.sh first:
```bash
source ~/.jira-helper/jira-helper.sh && get_jira_issue PANK-1234
```

### Problem: JIRA_HELPER_PATH not set

**Symptom:** `JIRA_HELPER_PATH: unbound variable`

**Solution:** The path should be in `.claude/config`. If missing:
```bash
export JIRA_HELPER_PATH="$HOME/.jira-helper/jira-helper.sh"
```

Then re-run installer to persist:
```bash
cd ~/repos/platform-utilities/jira-helper && ./install.sh
```

### Problem: Credentials not found

**Symptom:** `~/.jira: No such file or directory`

**Solution:** Run credentials setup:
```bash
cd ~/repos/platform-utilities/jira-helper && ./setup-credentials.sh
```

### Problem: Want to customize directives

**Solution:** Edit `~/.claude/config` directly. The installer will only update the `JIRA_HELPER_PATH` line on subsequent runs, preserving your customizations.

## Development vs Installed Locations

**IMPORTANT:** There are two locations for jira-helper code:

### Development Location (Edit Here)
```
~/repos/platform-utilities/jira-helper/
├── jira-helper.sh          # Edit this
├── lib/                    # Edit this
├── templates/              # Edit this
├── install.sh              # Edit this
└── ...
```

### Installed Location (Don't Edit)
```
~/.jira-helper/
├── jira-helper.sh          # Generated by installer
├── lib/                    # Generated by installer
├── templates/              # Generated by installer
└── .atlassian-cache/       # Runtime cache
```

**Workflow:**
1. Make changes in `~/repos/platform-utilities/jira-helper/`
2. Run `./install.sh` to deploy changes to `~/.jira-helper/`
3. Restart Claude Code session to pick up changes

## Cache Structure

jira-helper uses intelligent caching at `~/.jira-helper/.atlassian-cache/`:

**TTL-based caches:**
- `metrics-*.json` - Query results with time-based expiry
- 5 min: EOD reports, personal metrics
- 30 min: Pain points
- 1 hour: Standard metrics
- 6 hours: Age metrics

**Timestamp-based caches:**
- `jira-<key>.json` - Individual issue data
- `jira-<key>.timestamp` - Last modified time
- `confluence-<id>.json` - Individual page data
- `confluence-<id>.timestamp` - Last modified time

**Cache invalidation:**
- Automatic when remote resource is newer
- Manual: `rm -rf ~/.jira-helper/.atlassian-cache/*`

## Why This Approach?

### vs. MCP (Model Context Protocol)

**jira-helper advantages:**
- ✅ **$0 cost** - No subscription fees
- ✅ **Faster** - Direct API + local cache (sub-second vs 2-5s MCP)
- ✅ **Simpler** - One file install vs MCP server setup
- ✅ **Richer** - Metrics, reports, safety guardrails
- ✅ **Smaller** - 130KB vs 50MB+ MCP framework
- ✅ **Portable** - Pure bash, no Node.js/Python runtime

**MCP use cases:**
- Protocol standardization across multiple AI tools
- Already invested in MCP infrastructure
- Need integration with other MCP servers

### vs. Hardcoded Function List in Config

**Dynamic discovery advantages:**
- ✅ **Always in sync** - `jira_helper help` reflects actual code
- ✅ **Simpler config** - 3 lines vs 50+ lines
- ✅ **Easier maintenance** - Update code, not config
- ✅ **Less context** - Config stays minimal

## Additional Resources

- [README.md](../README.md) - Full user documentation
- [FUTURE-ENHANCEMENTS.md](../FUTURE-ENHANCEMENTS.md) - Roadmap and planned features
- [JiraHelperRC2-Modularization.md](./JiraHelperRC2-Modularization.md) - Technical architecture

## Support

For issues or questions:
1. Check `jira_helper help` for command syntax
2. Review this document for common problems
3. Check the GitHub repository for known issues
4. File a new issue with reproduction steps
