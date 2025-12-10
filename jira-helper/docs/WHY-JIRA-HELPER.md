# Why jira-helper?

CLI tool for direct Jira/Confluence API access via Claude or command line. Supports markdown formatting, metrics, and report generation.

## The Problem

Teams waste massive time on Jira/Confluence:
- **Writing formatted comments takes 10+ minutes per ticket** - drafting in ChatGPT, copying, converting formatting, pasting
- **Atlassian's editor is painful** - no markdown, awkward formatting toolbar, constant context switching
- **MCP servers** require complex setup, hosting, and subscription costs
- **Manual CLI tools** need memorizing commands and syntax
- **Claude lacks native Atlassian access** without expensive intermediaries

## The Solution: jira-helper

A single bash script that bridges the gap between:
1. **CLI efficiency** - Fast, cached, tab-completed commands
2. **Claude intelligence** - Natural language Jira operations
3. **Direct API access** - No intermediary servers or protocols

### Core Value Proposition

```
Zero Cost + Fast Response + Rich Features = jira-helper
```

### Direct Jira Comment Writing

| Old Workflow (10+ minutes) | New Workflow (30 seconds) |
|----------------------------|---------------------------|
| 1. Ask ChatGPT to write a comment | 1. Tell Claude: "add a detailed update to PANK-1797 about the authentication fix" |
| 2. Copy the output | 2. Done. Comment posted with perfect formatting. |
| 3. Open Jira in browser | |
| 4. Fight with Atlassian's formatting toolbar | |
| 5. Paste and reformat | |
| 6. Submit | |

**That's 10+ minutes saved per ticket. Every. Single. Time.**

## Why Choose jira-helper Over MCP?

### Performance & Cost

| Metric | Atlassian MCP | jira-helper |
|--------|---------------|-------------|
| **Monthly Cost** | Claude Pro subscription + hosting | $0 |
| **Response Time** | 2-5s per request | Sub-second (when cached) |
| **Caching** | Server-side caching | Aggressive (5min-6hr TTL) |
| **Setup Time** | Multi-step server config | 2 minutes |
| **Size** | 50MB+ framework | 200KB (170KB main + 30KB libs) |

### Developer Experience

**jira-helper advantages:**
- **Smart tab completion** - Type `jira-helper issue <TAB>` and see your 10 most recent tickets with titles
- **Hierarchical commands** - Logical grouping like `jira-helper metrics volume`, `jira-helper issue comment`
- **CLI + Claude dual mode** - Works both ways without configuration overhead
- **Single config file** - One `~/.jira` file vs multiple MCP server/client configs

**What you can do:**

```
# CLI Mode
jira-helper issue PANK-1797
jira-helper metrics volume 7
jira-helper eod 1 slack_compact

# Claude Mode (natural language)
"show issue PANK-1797"
"generate my EOD report for yesterday"
"what are the blocked tickets in PANK?"
```

### Feature Comparison

| Feature Category | Atlassian MCP | jira-helper |
|------------------|---------------|-------------|
| **Metrics** | Basic queries only | 7 types (volume, age, priority, churn, personal, painpoints, creation) |
| **Reports** | Not available | EOD reports (3 formats: default, slack_compact, slack_plain) |
| **Markdown** | Limited | Full support (headers, bold, code, lists, tables → ADF) |
| **Safety** | No guardrails | Confirmation prompts for unrelated tickets, `--yes` bypass |
| **Confluence** | Read/write only | Source file mapping, bidirectional sync tracking |
| **Workspaces** | Single instance | Auto-discovery, centralized cache, cross-repo stats |
| **Search** | JQL only | Text search within your issues |

### Security & Privacy

**jira-helper:**
- Direct API calls (no intermediary server)
- API token stays local in `~/.jira` with 600 permissions
- Smaller attack surface (single bash script)
- No data leaves your machine except direct API calls

**MCP:**
- Requires MCP server (additional attack surface)
- Protocol-level abstraction (added complexity)
- Server hosting (additional security considerations)

## Real-World Use Cases

### 1. Daily Standup Automation
```
# Generate yesterday's work summary in 2 seconds
jira-helper eod 1 slack_compact

# Output:
# PANK-1797: Add jira-helper library (InProg→Done)
# PANK-1810: Fix cache staleness (Blkd→InProg)
# PANK-1485: Route53 TLS setup (InProg)
```

### 2. Team Health Monitoring
```
# Check team velocity and bottlenecks
jira-helper metrics volume 7
jira-helper metrics painpoints PANK
jira-helper metrics priority 14 PANK

# Identify: 5000+ created, 594 closed, 42 blocked
```

### 3. Natural Language with Claude
```
User: "Show me PANK-1797 and add a comment about completing the modularization"

Claude:
- Runs: get_jira_issue PANK-1797
- Shows formatted output
- Runs: add_jira_comment PANK-1797 "Completed modularization work..."
- Posts comment with rich markdown formatting
```

### 4. Interactive Comment Posting
```
jira-helper issue comment PANK-1797 "Fixed authentication bug"

# Prompts for style:
# 1) Concise/Direct
# 2) Formal/Professional
# 3) Friendly/Casual
# 4) Original (no changes)

# Applies style and posts to Jira
```

## When to Use MCP Instead

**Use MCP if:**
- You're already heavily invested in MCP infrastructure
- You need protocol-level integration with other MCP servers
- You value protocol standardization over performance and cost
- You require cross-platform server/client separation

**The real power:** You can use both! Keep jira-helper for daily workflow (speed, CLI, reports) and MCP for protocol-level integrations.

## Production Readiness

### Code Stats
- **5,100+ lines** of bash (5,124 main + 1,054 in libs)
- **47 public functions** with test coverage
- **72 automated tests** (syntax, dependencies, functions, integration)
- **5 modular lib files** for maintainability
- **Cross-platform** (macOS and Linux, auto-detects GNU vs BSD tools)
- **TTL-based caching** (5min to 6hr, configurable)

### Team Distribution
```
# Add to your repo
git clone <your-repo>
cd <repo>/jira-helper
./install.sh          # Installs to ~/.jira-helper/
./setup-credentials.sh # Set up API token

# Team members run the same
# Everyone shares the same code, separate credentials
```

### Documentation
- **README.md** - Comprehensive function reference
- **CHANGELOG.md** - Release notes and version history
- **docs/CLAUDE.md** - Claude Code integration guide
- **docs/FunctionCoverageAnalysis.md** - Coverage verification
- **run-tests.sh** - Automated test suite (quick and full modes)

## Key Technical Highlights

### 1. Intelligent Caching
```
# TTL-based caching eliminates redundant API calls
- 5 min: EOD reports, personal metrics (frequently changing)
- 30 min: Pain points (moderate change rate)
- 1 hour: Standard metrics (volume, priority, churn)
- 6 hours: Age metrics (550 pages, slow changing)

# Result: 0 API calls when cache is fresh
```

### 2. Full Pagination Support
```
# Handles large datasets (55,000 tickets, 550 API pages)
# Automatic pagination with progress tracking
# Configurable max_pages for testing
```

### 3. Cross-Platform Compatibility
```
# Works on both macOS (BSD) and Linux (GNU)
# Auto-detects and prefers GNU tools (gawk, gsed, ggrep, gdate, gfind)
# Provides brew install instructions for macOS if missing GNU tools
# Graceful fallback to BSD tools on macOS
```

### 4. Rich Markdown to ADF Conversion
```
# Converts markdown to Atlassian Document Format
# Supports: headers, bold, italic, code, lists, links, tables
# Preserves formatting in Jira comments
```

## Cost Analysis

**Typical usage pattern:**
- Daily EOD reports: ~$0.00 (cached)
- Weekly metrics suite: ~$0.00 (cached)
- Claude-assisted workflow: ~$0.15/day (400-500 input tokens per operation)
- Monthly cost: **~$4.50** vs **$20+ for MCP** (Claude Pro + hosting)

**Efficiency gains:**
- **10+ minutes saved per formatted comment** (no ChatGPT copy-paste workflow)
- **5+ tickets per day with rich comments** = 50+ minutes saved daily
- **200+ hours/year saved per developer** on Jira operations alone
- **Value: $20,000-$40,000/year per developer** (at $100-200/hr rate)

**Real workflow comparison:**

| Task | Without jira-helper | With jira-helper |
|------|---------------------|------------------|
| Write detailed ticket update | 15 min (draft in ChatGPT, copy, format, paste) | 30 sec ("Claude, add update to PANK-1797") |
| Generate EOD report | 10 min (manual ticket review) | 5 sec (cached, formatted) |
| Add formatted comment | 10 min (markdown → Jira formatting) | 20 sec (Claude writes, posts directly) |

## Migration Path

### From Manual Jira Workflow
1. Install jira-helper: `./install.sh`
2. Set up credentials: `./setup-credentials.sh`
3. Start using CLI: `jira-helper issue PANK-1797`
4. Let Claude use it: "show issue PANK-1797"

### From MCP Atlassian Server
1. Keep MCP for protocol-level integrations
2. Use jira-helper for daily workflow (faster, cheaper)
3. No migration needed - both can coexist
4. Evaluate which tool fits your workflow better

## Getting Started

### Quick Start (2 minutes)
```
cd jira-helper
./install.sh
./setup-credentials.sh
jira-helper issue PANK-1797
```

### Claude Integration (automatic)
```
# install.sh configures ~/.claude/config automatically
# Just ask Claude: "show issue PANK-1797"
# Claude sources jira-helper.sh and uses functions
```

### Team Rollout (add to git)
```
# Commit jira-helper/ to your platform-utilities repo
# Team members run ./install.sh
# Everyone shares code, separate credentials
```

## FAQ

**Q: Does installation modify my `.claude/config` or other Claude settings?**

A: Yes, but safely. The installer adds a single `## Atlassian policy` section to `~/.claude/config` with BEGIN/END markers. Your existing config is backed up to `~/.claude/.backups/` before any changes. On subsequent installs, only the marked section is updated - your customizations outside the markers are preserved.

**Q: What if I already have MCP Atlassian tools installed?**

A: They coexist. The config tells Claude to prefer jira-helper functions over MCP when available. You can use both simultaneously - jira-helper for daily workflow (faster, cached) and MCP for protocol-level integrations.

**Q: How do I uninstall?**

A: Delete `~/.jira-helper/` directory and remove the `## Atlassian policy` section from `~/.claude/config`. Your API token in `~/.jira` is separate - revoke it at Atlassian if no longer needed.

**Q: Does this store my Atlassian credentials?**

A: Only your API token, stored locally in `~/.jira` with 600 permissions (read/write for you only). The token never leaves your machine except in direct API calls to Atlassian. No third-party services involved.

**Q: What happens if jira-helper breaks or I want to stop using it?**

A: Claude falls back to asking you for information or using MCP if available. Nothing destructive happens. You can also remove the Atlassian policy section from `.claude/config` and Claude won't try to use jira-helper.

**Q: Can I use this in CI/CD pipelines?**

A: Yes. Source `jira-helper.sh` and call functions directly. Set credentials via `~/.jira` or environment variables. Useful for automated ticket updates, deployment notifications, or release notes.

**Q: How do I update to a new version?**

A: Run `./install.sh` again from the updated repo. It preserves your `~/.jira` credentials and updates only the managed section of `.claude/config`.

**Q: What if my team uses a different shell (fish, zsh, etc.)?**

A: jira-helper requires bash for execution. Functions work in bash scripts regardless of your interactive shell. Claude executes commands in bash by default.

## Support & Community

### Documentation
- [README.md](../README.md) - Function reference
- [docs/CLAUDE.md](CLAUDE.md) - Claude integration guide
- [CHANGELOG.md](../CHANGELOG.md) - Version history

### Testing
- Quick mode: `./run-tests.sh --quick` (no API calls)
- Full mode: `./run-tests.sh` (requires credentials)
- 72 tests: syntax, dependencies, all functions, integration

### Security
- API tokens in `~/.jira` (permissions 600)
- Never commit credentials
- Revoke at: https://id.atlassian.com/manage-profile/security/api-tokens

## Bottom Line

**jira-helper delivers:**
- **Zero cost** (vs $20+/month MCP)
- **Fast response** (aggressive caching, direct API)
- **Rich features** (7 metrics, 3 report formats, markdown)
- **Tested** (72 automated tests)
- **Claude-native** (natural language operations)
- **Team-friendly** (git distribution, simple setup)

Install time: 2 minutes. Setup: Single config file.

---

**Built with:** Bash, jq, curl.

**License:** Share freely within your organization.

**Questions?** Check the docs or ask Claude: "How do I use jira-helper for X?"
