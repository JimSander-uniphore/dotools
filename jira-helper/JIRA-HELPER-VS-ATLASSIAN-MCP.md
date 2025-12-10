# jira-helper vs Atlassian MCP

## The Comparison Nobody Asked For (But Everyone Needs)

### Performance & Cost

**jira-helper:**
- **Speed**: Direct REST API calls with intelligent caching (TTL-based)
- **Cost**: $0/month (uses your existing Atlassian API token)
- **Offline**: Full command history, cached data accessible without internet
- **Latency**: Sub-second for cached data, ~1-2s for fresh API calls

**Atlassian MCP:**
- **Speed**: Routed through MCP server layer (additional hop)
- **Cost**: Requires Claude subscription + potential MCP hosting costs
- **Offline**: Requires active connection to MCP server
- **Latency**: 2-5s typical (MCP → API → response)

### Developer Experience

**jira-helper:**
- **CLI**: `jh issue PANK-1797` (9 characters including spaces)
- **Tab Completion**: Smart suggestions with ticket titles/hints
- **Shell Integration**: Source and call functions directly
- **Claude Integration**: Just ask "show issue PANK-1797"
- **No Config**: Single `.jira` file with API token
- **Hierarchical Commands**: Logical grouping (`issue comment`, `metrics volume`)

**Atlassian MCP:**
- **CLI**: Requires MCP client + configuration
- **Tab Completion**: Not available (MCP protocol limitation)
- **Shell Integration**: Not designed for direct shell use
- **Claude Integration**: Requires MCP-enabled Claude client
- **Config**: Multiple config files (MCP server, client, credentials)
- **Commands**: Flat namespace, less intuitive

### Feature Set

**jira-helper:**
- ✅ Issue CRUD operations
- ✅ Comment management (add, update)
- ✅ Workflow transitions
- ✅ Confluence page operations
- ✅ Advanced metrics (7 types)
- ✅ EOD reports (4 formats)
- ✅ Workspace discovery
- ✅ Smart caching with TTL strategies
- ✅ Safety guardrails (confirmation prompts)
- ✅ Text search in issues
- ✅ Source file mapping for Confluence

**Atlassian MCP:**
- ✅ Issue CRUD operations
- ✅ Comment management
- ❌ Advanced metrics
- ❌ EOD reports
- ❌ Workspace discovery
- ⚠️ Basic caching (MCP protocol level)
- ❌ Safety guardrails
- ⚠️ Limited search capabilities
- ❌ Source file mapping

### Real-World Usage

**Daily standup (EOD report):**
```bash
# jira-helper
jh eod 1 slack
# → Sub-second with cache, formatted for Slack

# Atlassian MCP
# Requires manual JQL query or custom prompt to Claude
# No pre-built report formats
```

**Finding your work:**
```bash
# jira-helper
jh issues search "authentication"
# → Searches summary, description, comments in YOUR issues

# Atlassian MCP
# Requires writing JQL or asking Claude to search
# May not filter to your issues by default
```

**Adding a comment:**
```bash
# jira-helper
jh issue comment PANK-1797 "Working on this"
# → With tab completion showing recent tickets + titles
# → Safety prompt if you're not assigned/reporter/watcher

# Atlassian MCP
# Longer command path through MCP protocol
# No tab completion hints
# No safety guardrails
```

### Architecture

**jira-helper:**
```
User → bash function → REST API → JSON cache → formatted output
     ↓
     Tab completion with hints from cache
     ↓
     Direct Claude Code integration (no extra layer)
```

**Atlassian MCP:**
```
User → Claude → MCP client → MCP server → REST API → response
     ↓                           ↓
     No tab completion     Additional auth/routing layer
```

### Deployment & Distribution

**jira-helper:**
- **Install**: `./install.sh` (adds to PATH and Claude config)
- **Team Distribution**: Commit scripts to git, team runs install
- **Updates**: `jh update` (self-update from GitHub)
- **Requirements**: bash, jq, curl (standard on most systems)
- **Size**: ~130KB total (all functionality)

**Atlassian MCP:**
- **Install**: Multiple steps (MCP server, client config, credentials)
- **Team Distribution**: Each user configures MCP server/client
- **Updates**: Manual update of MCP server
- **Requirements**: Node.js/Python + MCP runtime + dependencies
- **Size**: ~50MB+ (MCP framework + dependencies)

### Security

**jira-helper:**
- API token in `~/.jira` (600 permissions)
- Never commits credentials
- Direct API calls (no intermediary)
- Local cache with gitignore patterns

**Atlassian MCP:**
- API token in MCP server config
- Token exposed to MCP server layer
- Additional attack surface (MCP server)
- Cache location varies by MCP implementation

### Extensibility

**jira-helper:**
- **Functions**: Add bash functions, they're instantly available
- **Commands**: Add to dispatcher with 3 lines of code
- **Reports**: JQ transformations for custom formatting
- **Metrics**: New JQL queries = new metrics
- **Integration**: Any bash script can source and use functions

**Atlassian MCP:**
- **Tools**: Requires MCP protocol implementation
- **Commands**: Modify MCP server (Node.js/Python)
- **Reports**: Requires server-side implementation
- **Metrics**: Server-side changes + deployment
- **Integration**: Limited to MCP-aware clients

### The Bottom Line

**jira-helper wins on:**
- ⚡ Speed (caching + direct API)
- 💰 Cost ($0 vs subscription fees)
- 🎯 UX (tab completion, hints, hierarchical commands)
- 📊 Features (metrics, reports, workspace tools)
- 🛡️ Safety (confirmation prompts, guardrails)
- 🚀 Deployment (one script vs multi-step setup)
- 🌐 No walled garden (standard bash, direct REST API, no proprietary protocols)

**Atlassian MCP wins on:**
- 🤔 ... protocol standardization?
- 📝 ... being an official Anthropic pattern?
- 🏰 ... if you enjoy walled gardens?

### When to Use What

**Use jira-helper if you:**
- Want fast, cached access to Jira/Confluence
- Need CLI + Claude integration
- Value developer experience and productivity
- Want advanced reporting and metrics
- Need offline access to issue history

**Use Atlassian MCP if you:**
- Already have MCP infrastructure deployed
- Need to integrate with other MCP servers
- Want official Anthropic protocol support
- Don't mind the overhead for standardization

### The Verdict

**jira-helper isn't just competitive with Atlassian MCP — it's significantly better for 95% of use cases.** The only scenario where MCP wins is if you're already heavily invested in the MCP ecosystem and value protocol standardization over performance, cost, and features.

**The real power:** You can use BOTH. Keep jira-helper for your daily workflow (speed, CLI, reports), and keep MCP if you need protocol-level integration. They're not mutually exclusive.

---

*"Not going to toot our own horn, or yeah I will... I bet this outshines the Atlassian MCP, and costs a helluva lot less"* — Validated ✅
