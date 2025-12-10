# CHANGELOG

## [1.0.0-rc2] - 2025-11-11

### Added
- **lib/ modular architecture** (5 modules, 1,054 lines extracted)
  - `lib/markdown-to-adf.sh` - Markdown to Atlassian Document Format conversion
  - `lib/markdown-to-html.sh` - Markdown to HTML for Confluence
  - `lib/jira-comment-helpers.sh` - Comment API operations
  - `lib/git-helpers.sh` - Git integration utilities
  - `lib/remediation-helpers.sh` - Security remediation workflows
- **Comprehensive test suite** (`run-tests.sh`)
  - 72 tests: syntax, dependencies, all 47 public functions, 5 lib functions
  - Quick mode (--quick) for CI/PR checks without API calls
  - Full mode with API connectivity tests
- **GNU tools detection** for macOS
  - Auto-detects missing GNU tools (gawk, gsed, ggrep, gdate, gfind)
  - Provides brew install instructions
  - Suppression via `JIRA_HELPER_NO_GNU_WARNING=true`
- **Enhanced Claude Code integration**
  - Minimal 3-line `.claude/config` with dynamic function discovery
  - Smart installer that preserves user customizations
  - Comprehensive `docs/CLAUDE.md` integration guide
- **Documentation overhaul**
  - README.md with MCP comparison, usage examples
  - `docs/FunctionCoverageAnalysis.md` - Source of truth hierarchy
  - `docs/ClaudePRReview-PartDeux.md` - Token usage analysis
  - `docs/JiraHelperRC2-Modularization.md` - Architecture details
- **EOD report templates** in repository
  - Template metadata system (TEMPLATE/SLUG/DESCRIPTION headers)
  - Git protections for .example files

### Fixed
- **BSD/GNU compatibility** (60 command variable fixes)
  - awk → $AWK (3 instances)
  - sed → $SED (6 instances)
  - grep → $GREP (17 instances)
  - date → $DATE (14 instances)
  - find → $FIND (14 instances)
  - xargs → $XARGS (6 instances)
- **Cache location** from repo-specific to `$HOME/.jira-helper/.atlassian-cache/`
  - Eliminates dev vs installed confusion
  - Single cache location for all installations

### Changed
- **Reduced main script** from 5,704 → 5,103 lines (-601 lines, -10.5%)
- **Consolidated comment functions** with unified handler
- **Organized docs** into standard structure (docs/, templates/, lib/)

### Technical Metrics
- **Session cost**: ~$0.67 (124K tokens) vs $7 for 1.5M token PR review
- **Test coverage**: 100% of public functions (47/47)
- **Line reduction**: Net -23 lines after modularization
- **Module count**: 5 lib modules, 1,054 lines extracted

### Migration Notes
- No breaking changes - all existing functions work identically
- Cache automatically migrates to `$HOME/.jira-helper/.atlassian-cache/`
- Run `./install.sh` to update `.claude/config` (preserves customizations)
- GNU tools recommended but BSD fallback works

## [1.0.0-rc1] - Prior
Initial release candidate with core functionality.

