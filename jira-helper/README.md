# Atlassian API Cache & Helper Functions

**Give Claude direct access to your Jira/Confluence Cloud instance.**

Comprehensive CLI tool with smart caching, tab completion, and native Claude Code integration. Just ask Claude to show issues, generate reports, update tickets, or search Confluence - no command syntax needed, no MCP overhead, no subscription fees.

**Claude can now:**
- Read and update your Jira tickets
- Search and fetch Confluence documentation
- Generate EOD reports from your work
- Run metrics and analyze team health
- All through natural language - just ask

**Key Features:**
- **[Claude Code integration](#4-usage)** - Natural language Jira operations through AI (pre-configured directives)
  - [Why better than MCP](#why-jira-helper-vs-atlassian-mcp): $0 cost, faster (direct API + caching), richer features (metrics, reports), simpler deployment
- **[Smart tab completion](#smart-tab-completion)** - Type `jira-helper issue <TAB>` and see your 10 most recent tickets
- **[Rich markdown in comments](#rich-comments-with-markdown)** - Headers (##), bold (**text**), code (`text`), bullets automatically convert to Jira formatting
- **[Intelligent caching](#cache-structure)** - 5-minute refresh for searches, timestamp-based for individual resources
- **[End-of-day reports](#daily-standup-reports)** - Generate standup updates in seconds (default, slack_compact, slack_plain)
- **[Comprehensive metrics](#metrics-and-analysis)** - Volume, age, priority health, churn, personal workload, pain points
- **[Confluence integration](#confluence-integration)** - Search pages, map to source files, track documentation updates
- **[Safety guardrails](#available-functions)** - Prompts before modifying tickets you're not watching (bypass with --yes)
- **[Issue creation](#issue-creation-with-subtasks)** - Create tickets and subtasks with proper parent linking

**Three ways to use:**
1. **Claude**: Just ask "show issue PANK-1797" or "generate my EOD report"
2. **CLI**: `jira-helper issue PANK-1797`
3. **Shell**: `source jira-helper.sh && get_jira_issue PANK-1797`

## Table of Contents
- [Cache Structure](#cache-structure) - How caching works
- [Quick Start](#quick-start) - Installation and setup
- [Available Functions](#available-functions) - What you can do
- [Examples](#examples) - Common use cases
- [Team Distribution](#team-distribution) - Share with your team

## Cache Structure

- `jira-<issue-key>.json` - Cached Jira issue data
- `jira-<issue-key>.timestamp` - Last modified timestamp
- `confluence-<page-id>.json` - Cached Confluence page data
- `confluence-<page-id>.timestamp` - Last modified timestamp

## Usage Pattern

1. Check if cache file exists and timestamp is recent
2. If stale or missing, fetch from API
3. Save response and timestamp
4. Return data

## Cache Invalidation

Cache is invalidated when:
- File doesn't exist
- Cache file is older than 5 minutes (for search results)
- Remote resource has newer modified time (for individual issues/pages)
- Manual deletion of cache files

## Example

```bash
# Cache Jira issue
CACHE_DIR=~/repos/jds-sandbox1/.atlassian-cache
CACHE_FILE="${CACHE_DIR}/jira-PANK-1334.json"

# Check if needs refresh
if [ -f "$CACHE_FILE" ]; then
  # Compare timestamps
  CACHED_TIME=$(cat "${CACHE_FILE}.timestamp" 2>/dev/null || echo 0)
  REMOTE_TIME=$(curl -s ... | jq -r '.fields.updated')

  if [ "$REMOTE_TIME" != "$CACHED_TIME" ]; then
    # Refresh cache
  fi
fi
```

## Notes

- All cache files are gitignored
- Timestamps stored separately for easy comparison
- JSON files contain full API responses

## Quick Start

### 1. Installation
```bash
cd jira-helper
./install.sh
```
Installs to `~/.jira-helper/`, adds to shell profile, and configures Claude Code.

### 2. Credentials
```bash
./setup-credentials.sh
```
Creates `~/.jira` with your API token. Get token at: https://id.atlassian.com/manage-profile/security/api-tokens

### 3. CLI Installation (Optional)
Make `jira-helper` available as a system-wide command:
```bash
# Create symlink in your PATH (choose one location)
sudo ln -s "$(pwd)/jira-helper" /usr/local/bin/jira-helper
# OR for user-only install:
mkdir -p ~/bin
ln -s "$(pwd)/jira-helper" ~/bin/jira-helper
# (ensure ~/bin is in your PATH)
```

### 4. Usage

**Option A: With Claude** (recommended)
Just ask Claude in natural language:
- "show issue PANK-1797"
- "generate my EOD report for yesterday"
- "what are the blocked tickets in PANK?"
- "add a comment to PANK-1797 about the authentication fix"
- "show my recent Jira updates"

Claude has full context and will use jira-helper functions automatically. No command syntax needed.

**Option B: CLI Command** (if installed in step 3)
```bash
# View issues
jira-helper issue PANK-1797              # Show issue (formatted)
jira-helper issue PANK-1797 --json       # JSON output
jira-helper issue transitions PANK-1797  # Show workflow transitions

# Search issues
jira-helper issues                       # Your updates today
jira-helper issues mine 7                # Last 7 days
jira-helper issues search "jira-helper"  # Text search in your issues
search_newly_assigned_issues 30          # Newly assigned, not yet touched

# Confluence docs
jira-helper doc 4214128641               # Get page
jira-helper doc source 4214128641        # Get source path
jira-helper doc set-source 4214128641 /path/doc.md
jira-helper docs                         # Your page updates
jira-helper docs sources                 # List source mappings

# Reports and metrics
jira-helper eod 1 slack              # Daily standup
jira-helper metrics volume 7         # Volume metrics
jira-helper metrics personal         # Your workload
```

### Smart Tab Completion
Press TAB after commands to see suggestions:
- `jira-helper issue` - `transitions` subcommand + your 10 most recent **tickets** (PROJECT-123 format)
- `jira-helper doc` - `source`/`set-source` subcommands + your 10 most recent **page IDs** (numeric)
- All suggestions filtered from cache - only shows valid, recently accessed items

**Option C: Shell Functions** (source in shell)
```bash
source "$CACHE_HELPER_PATH"
eod_report
get_jira_issue PANK-1797
```

## Available Functions

### Reporting
- `eod_report [days] [format]` - End of day report (formats: default, slack_compact, slack_plain)

### Jira Metrics
Access via `jira-helper metrics <subcommand>`:
- `volume [days] [project]` - Created/closed/open counts
- `creation [days]` - Top creators and trends
- `age [project] [max_pages]` - Age distribution
- `priority [days] [project]` - Priority health
- `churn [days] [project]` - Reopened tickets
- `personal [email]` - Your workload
- `painpoints [project]` - Blocked and unassigned

### Ticket Operations
- `get_jira_issue TICKET-123 [--json]` - Fetch ticket (formatted or JSON)
- `show_jira_issue TICKET-123` - Show ticket (formatted text)
- `search_my_jira_updates [days]` - Your updates
- `search_newly_assigned_issues [days]` - Newly assigned issues you haven't touched
- `create_jira_ticket PROJECT "Summary" "Desc" "Task"` - Create ticket
- `add_jira_comment TICKET-123 "Comment" [--yes|--force]` - Add comment (prompts if unrelated)
- `update_jira_issue TICKET-123 <field> <value> [--yes|--force]` - Update field (prompts if unrelated)
- `update_jira_summary TICKET-123 "New summary" [--yes|--force]` - Update issue summary (prompts if unrelated)
- `update_jira_description TICKET-123 "New description" [--yes|--force]` - Update issue description (prompts if unrelated)
- `update_jira_comment TICKET-123 <id> "Text" [--yes|--force]` - Update comment (prompts if unrelated)

**Safety Guardrail**: Write operations prompt for confirmation if you're not the assignee, reporter, or watcher. Use `--yes` or `--force` to bypass.

### Confluence Operations
- `get_confluence_page PAGE_ID` - Fetch page
- `search_my_confluence_updates [days]` - Your page updates
- `get_confluence_source PAGE_ID` - Get source file path
- `set_confluence_source PAGE_ID <path>` - Set source mapping
- `list_confluence_sources` - List all source mappings

## Caching Details

### TTL Strategy
- 5 min: EOD reports, personal metrics
- 30 min: Pain points
- 1 hour: Standard metrics
- 6 hours: Age metrics (550 pages)

### Cache Files
- `metrics-*.json` - TTL-based query caches
- `jira-<key>.json` - Timestamp-based ticket caches
- `confluence-<id>.json` - Timestamp-based page caches

## Examples

### Quick Issue Lookups
```bash
# View issues
jira-helper issue PANK-1797                    # Show formatted (summary, description, status, etc.)
jira-helper issue PANK-1797 --json             # Raw JSON for scripting
jira-helper issue transitions PANK-1797        # Available workflow transitions

# Search your updates
jira-helper issues                             # Today's activity
jira-helper issues mine 7                      # Last 7 days
jira-helper issues search "authentication"     # Text search in your issues

# Find newly assigned issues you haven't touched
search_newly_assigned_issues                   # Last 7 days (default)
search_newly_assigned_issues 30                # Last 30 days
```

### Rich Comments with Markdown
```bash
# Add formatted comment (interactive style selection)
jira-helper issue comment PANK-1797 "## Progress Update

Fixed the authentication bug. Changes:
- Updated `validateToken()` function
- Added **retry logic** for transient failures
- See details: https://github.com/org/repo/pull/123"

# Result in Jira: Proper headers, bullets, bold text, inline code, clickable links
```

### Daily Standup Reports
```bash
# Generate EOD report
jira-helper eod 1                    # Yesterday's work (formatted)
jira-helper eod 1 slack_compact      # For Slack (compact)
jira-helper eod 7 slack_plain        # Weekly summary (plain text)

# Example output:
# PANK-1797: Add jira-helper library (In Progress)
# PANK-1810: Fix cache staleness (Done)
# PANK-1485: Route53 TLS setup (In Progress)
```

### Metrics and Analysis
```bash
# Team health
jira-helper metrics volume 7         # Created/closed/open counts (last 7 days)
jira-helper metrics priority 14 PANK # Priority distribution (last 14 days)
jira-helper metrics painpoints PANK  # Blocked and unassigned tickets

# Personal workload
jira-helper metrics personal         # Your open tickets and age distribution
jira-helper metrics personal user@company.com  # Check teammate's workload

# Historical analysis
jira-helper metrics age PANK 550     # Age distribution across 550 pages
jira-helper metrics churn 30 PANK    # Reopened tickets (last 30 days)
```

### Confluence Integration
```bash
# Browse documentation
jira-helper docs                               # Your recent page updates
jira-helper docs mine architecture             # Search your pages for "architecture"
jira-helper doc 4214128641                     # Get specific page content

# Source file mapping (link Confluence to markdown files)
jira-helper doc set-source 4214128641 /path/to/docs/api.md
jira-helper doc source 4214128641              # Returns: /path/to/docs/api.md
jira-helper docs sources                       # List all mappings
```

### Issue Creation with Subtasks
```bash
# Create parent task
jira-helper issue create PANK "Implement OAuth" "Add OAuth 2.0 authentication" "Story"
# Returns: PANK-1234

# Create subtasks
jira-helper issue create PANK "Update auth middleware" "Modify middleware to support OAuth" "Sub-task" PANK-1234
jira-helper issue create PANK "Add OAuth endpoints" "Create /oauth/authorize and /oauth/token" "Sub-task" PANK-1234
```

## Team Distribution

Share jira-helper with your team via version control:

1. **Files in version control:**
   ```
   jira-helper/
   ├── jira-helper.sh
   ├── jira-helper-completion.sh
   ├── install.sh
   ├── setup-credentials.sh
   ├── run-tests.sh
   └── README.md
   ```

2. **Team members clone and install:**
   ```bash
   git clone <your-repo>
   cd <repo>/jira-helper
   ./install.sh          # Installs to ~/.jira-helper/
   ./setup-credentials.sh # Set up API token
   ```

3. **Gitignore** (cache files are auto-ignored by install location):

## Security
- API tokens in `~/.jira` with permissions 600
- Never commit `~/.jira` to git
- Revoke at: https://id.atlassian.com/manage-profile/security/api-tokens

## Usage Tracking (4-Week Pilot)

**Optional and Transparent**: Help improve jira-helper by enabling anonymous usage tracking during the 4-week pilot period.

### What's Tracked
- Function names (e.g., `eod_report`, `jira_metrics_volume`)
- Timestamps and success/failure status

### What's NOT Tracked
- Ticket numbers, descriptions, or any Jira/Confluence content
- API tokens or credentials
- Any personally identifiable information

### How It Works
- **Opt-in during installation** - Prompted when running `./install.sh`
- **Local storage only** - Data stays on your machine at `~/jira-helper/.usage-log`
- **Auto-expires** - Tracking automatically stops after 4 weeks (2025-12-06)
- **View anytime** - Run `jira_helper_stats` to see your usage
- **Easy opt-out** - `unset JIRA_HELPER_TRACK_USAGE`

### Enable/Disable
```bash
# Enable tracking
export JIRA_HELPER_TRACK_USAGE=true

# Disable tracking
unset JIRA_HELPER_TRACK_USAGE

# View your stats
jira_helper_stats
```

### Privacy
Your data stays local. Share it only if you choose to:
```bash
cat ~/jira-helper/.usage-log | mail -s "Usage Stats" team@company.com
```

## Why jira-helper vs Atlassian MCP?

jira-helper outperforms Atlassian MCP for most use cases. Here's why:

### Performance & Cost
- **Speed**: Direct REST API calls with intelligent caching (sub-second for cached data vs 2-5s MCP latency)
- **Cost**: $0/month using your Atlassian API token (MCP requires Claude subscription + potential hosting costs)
- **Offline**: Cached data accessible without internet, full command history available locally
- **Latency**: No MCP server intermediary, direct API communication

### Developer Experience
- **Tab completion**: Smart suggestions with ticket titles and hints (not available in MCP)
- **Hierarchical commands**: Logical grouping like `jh issue comment`, `jh metrics volume` (MCP has flat namespace)
- **CLI + Claude**: Works both ways without configuration overhead
- **Single config**: One `.jira` file vs multiple MCP server/client configs

### Features jira-helper Has (MCP Doesn't)
- Advanced metrics (7 types: volume, age, priority, churn, personal, painpoints)
- EOD reports (4 formats: default, slack_compact, slack_plain, json)
- Safety guardrails (confirmation prompts if you're not assigned/reporter/watcher)
- Text search within your issues
- Source file mapping for Confluence pages
- Workspace discovery

### Deployment
- **Install**: One command (`./install.sh`) vs multi-step MCP setup
- **Size**: 130KB vs 50MB+ (MCP framework + dependencies)
- **Requirements**: Standard bash, jq, curl vs Node.js/Python + MCP runtime
- **Team distribution**: Commit scripts to git, team runs install

### Security
- Direct API calls (no intermediary layer like MCP server)
- API token stays local in `~/.jira` with 600 permissions
- Smaller attack surface (no MCP server to compromise)

### When to Use MCP Instead
- You're already heavily invested in MCP infrastructure
- You need protocol-level integration with other MCP servers
- You value protocol standardization over performance and cost

**The real power**: You can use both. Keep jira-helper for daily workflow (speed, CLI, reports) and MCP for protocol-level integrations.

**Note**: Histogram outputs for age/priority distributions could use refinement - currently functional but not publication-ready.

See [full comparison](JIRA-HELPER-VS-ATLASSIAN-MCP.md) for detailed analysis.
