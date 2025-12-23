# Claude Code Configuration (NOT YAML)
# yaml-language-server: $schema=
# This is a plain text configuration file, not YAML
#
# CRITICAL: ~/CLAUDE.md is a SYMLINK to this file (~/.claude/config)
# NEVER replace ~/CLAUDE.md with a regular file - you will break the symlink
# To update config: Edit ~/.claude/config directly, or edit via ~/CLAUDE.md symlink
# To verify: ls -la ~/CLAUDE.md should show -> /Users/jimsander/.claude/config

## Priority order
1. Safety and org policies
2. Execution rules in this file
3. Tool usage rules
4. Style rules

## Execution rules
- Default: do not execute commands unless the user types exactly: `run <CommandName> {JSON}`.
- Read-only helpers are allowed without the `run` gate if they only read local caches or files and have no side effects.
- Local git read commands are allowed without `run` gate: git log, git show, git diff, git blame on repos in ~/repos
- Any network call, API mutation, or write to disk requires the `run` gate.
- If required args are missing, respond with the minimal JSON you need. Do not guess.
- If `confirm=true` is required and missing, ask once, then stop.

## Path portability
- CRITICAL: NEVER hardcode paths containing "OneDrive-UNIPHORESOFTWARESYSTEMSPVTLTD"
- This is a user-specific OneDrive sync path that breaks portability
- Use portable alternatives: ~/markdowns instead of ~/Library/CloudStorage/OneDrive-UNIPHORESOFTWARESYSTEMSPVTLTD/markdowns
- Check all path references in code for this pattern and replace with portable equivalents

## Kubernetes production safety
- NEVER create, modify, or delete Kubernetes resources in production environments
- Production environments include clusters with prod, production, or prd in the name/context
- Read-only operations (get, describe, logs) are allowed in production
- For production issues, provide analysis and remediation steps only - do not execute changes
- Creation/modification of resources must be done through proper CI/CD pipelines or by ops team

## Terraform Cloud credentials
- User credentials: ~/.terraform.d/credentials.tfrc.json (default, use for most operations)
- Admin credentials: ~/.terraform.d/tfc-owner-token.json (fallback if user credentials fail)
- CRITICAL: NEVER run terraform apply with admin credentials under any circumstances
- Pattern: Try operation with user credentials first, retry with admin credentials if auth fails
- Admin credentials are READ-ONLY for Claude usage (plan, state inspection only)
- Commands allowed with admin: terraform init, terraform plan, terraform state list, terraform state show, terraform workspace list
- Commands NEVER allowed with admin: terraform apply, terraform destroy, terraform import, terraform taint
- To use admin credentials: export TF_CLI_CONFIG_FILE=~/.terraform.d/tfc-owner-token.json && terraform <read-only-command>
- Always unset after use: unset TF_CLI_CONFIG_FILE

## Output contracts
- If a command defines an output format (json, tsv, text), return only that format.
- For errors, add an `error` field (for json) or start the single line with `ERROR:` (for tsv/text).

## Writing style
- CRITICAL: Folks complain AI docs are TOO MUCH to read. Write like a human engineer explaining to another engineer.
- Natural, conversational. Use commas and natural flow, not hyphens for separation (write "thing happened, other thing followed" not "thing happened - other thing followed")
- Short, scannable. Break long paragraphs into bullets. Get to the point fast.
- No corporate fluff: avoid "leverage", "utilize", "implement solutions", superlatives, marketing language
- No confirmatory language like "You're absolutely right" - prioritize technical accuracy over agreement
- No emojis or emoticons
- MANDATORY number formatting: Always use thousand separators (write $117,789 not $117789)
- Clean formatting: simple structure with clear headers, bullets, whitespace
- Avoid made-up metrics - if you don't have real data, don't invent percentages or time estimates
- CRITICAL: NEVER make definitive statements about system state without direct verification
  - Red flag phrases: "no longer exists", "has been deleted", "is completely removed", "namespace doesn't exist"
  - Only state what was directly observed or verified
  - When uncertain about system state, explicitly state "requires verification" or omit the claim
- CRITICAL: ALWAYS use the current date from the system context, NOT your knowledge cutoff date
  - System context shows current date in <env> tags
  - Knowledge cutoff is January 2025, but you must use actual current date from system
  - For current work, extract year from system date, don't assume based on knowledge cutoff

## Documentation standards
- Markdown links use `[short-name:line](url)` as the text.
- File references in VSCode: Use markdown link format [filename](path) with absolute paths for clickable links
- Be technically accurate; verify claims. Document current state before solutions.
- Remove line-number prefixes when editing file content.
- Avoid parentheses that auto-expand in Confluence.
- Use tables for comparisons (before/after, old/new). Keep column order consistent: "without solution" (left) vs "with solution" (right).
- Shell commands in markdown: Use fenced code blocks with bash/sh language tag. Use backslash line continuation for multi-line commands.
- Shell scripts in markdown: Ensure commands work when extracted and run. Test logic for error handling and exit codes.
- CRITICAL: Documentation in shared repos (platform-terraform, platform-flux, etc.) MUST reference Confluence URLs for published docs
  - NEVER reference local markdown paths like ~/markdowns/ in shared repo documentation
  - Local paths only work for the author, breaking accessibility for the team
  - Pattern: [Doc Title](https://uniphore.atlassian.net/wiki/spaces/PE/pages/PAGEID/Title) - Confluence
  - If doc is not yet published to Confluence, ask user where to publish (Platform Support Investigations is default for technical docs)

## Metadata tags for searchability
- Add structured metadata at end of markdown documents using `meta_<key>: <value>` format
- Enables grep-based search: `grep "meta_namespace:" ~/markdowns/*.md`
- Format: lowercase keys with underscores, no quotes unless value contains spaces
- Standard keys defined in meta_keys (use these when applicable for consistency)
- Drift categorization: meta_drift_type, meta_drift_impact, meta_drift_action
- Example:
  ```
  meta_keys: namespace,cluster,drift_count,severity
  meta_namespace: loadairbyte
  meta_cluster: uniphore-staging-us-eks-platform
  meta_drift_count: 2
  meta_severity: medium
  ```

## GitHub PR review workflow
- When asked to review a GitHub PR with inline comments:
  1. Fetch PR details and diff, cache to /tmp/pr-PRNUM-*.txt
  2. Analyze the PR and identify issues
  3. Create executable script in ~/reviews/PRNUM-0.sh with all inline comments
  4. Show user a summary of issues found
  5. Provide clickable link to the script
  6. Ask user if they want to execute the script to post comments
  7. Only execute script after user confirms
- Use gh api with --method POST to /repos/OWNER/REPO/pulls/PRNUM/comments
- Required headers: -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28"
- Calculate position by counting lines from @@ hunk start to target line (not absolute file line numbers)
- Get commit SHA: gh pr view PRNUM --repo REPO --json headRefOid -q .headRefOid
- Use -f for string parameters (body, commit_id, path) and -F for numeric (position)
- Add || echo "Failed to post comment N" for error handling
- Template: ~/reviews/TEMPLATE-pr-review.sh

## GitHub PR template conformance
- Template location: ~/markdowns/JSCRIPT-PR-Template.md
- Validator requirements: See PANK-2129 (~/markdowns/PANK-2129-Template-Comparison.md)
- CRITICAL: Validator requires bold field patterns (**Field**: value), NOT section headers (## Field)
- CRITICAL: Validator bug - avoid "How can this change be rolled back if needed?" text (triggers false positive)
- When asked to reformat a PR to match template:
  1. Fetch current PR: gh pr view PRNUM --repo OWNER/REPO --json title,body > /tmp/pr-PRNUM-current.json
  2. Reformat according to template structure, preserving all content
  3. MANDATORY bold fields (validator enforced):
     - **What changed**: (min 20 chars, no placeholders)
     - **Impact**: (min 20 chars, no placeholders)
     - **How tested**: (min 15 chars, or N/A)
     - **Plan for deployment**: (min 10 chars, accepts: CICD, N/A, Auto, Automatic, or Manual: <15+ char details>)
  4. Fix common issues:
     - Remove local file paths from Related section (use filename only with note about location)
     - Ensure "Pull Request Details" has brief description at top
     - Format rollback as "## Rollback" header with numbered steps ONLY (remove "How can this change be rolled back if needed?" text)
     - Keep validation commands in bash code blocks
  5. Save to /tmp/pr-PRNUM-updated.md
  6. Update PR: gh pr edit PRNUM --repo OWNER/REPO --body-file /tmp/pr-PRNUM-updated.md

## GitHub Actions workflow best practices
- ALWAYS use GitHub Actions context variables instead of API calls when available (more efficient, no rate limits)
- Common context variables: github.repository, github.event.pull_request.number, github.event.pull_request.user.login, github.event.pull_request.labels.*.name, github.sha, secrets.GITHUB_TOKEN
- Use actions/checkout with sparse-checkout for fetching specific files from other repos

## Function naming convention (APPLIES TO ALL CODE)
- MANDATORY: All user-facing functions MUST use pattern: `<namespace>_<action>[_<extended>]`
- **Namespace MUST be first**: `jira_`, `gh_`, `eod_`, etc.
- **Action is a verb**: add, get, list, find, analyze, batch, update, create, etc.
- **Extended is optional**: can be multiple words describing the target
- Examples:
  - CORRECT: `jira_add_labels`, `gh_get_repo`, `eod_generate_report`
  - WRONG: `add_jira_labels`, `get_gh_repo`, `generate_eod_report`
- Internal helper functions use underscore prefix: `_parse_url`, `_cache_result`
- This convention applies to: bash functions, Python functions, all helper libraries

## Helper development rules
- CRITICAL: NEVER edit production helper installations (jira-helper, gh-helper) in $HOME
- ALL development work MUST be done in ~/repos/jds-sandbox1/<helper-name>
- Production installs in ~/.jira-helper and ~/.gh-helper are READ ONLY for Claude
- NEVER hardcode user-specific paths: use ~ or $HOME, not /Users/jimsander or ~jimsander
  - CORRECT: ~/repos, $HOME/.config, ~/markdowns
  - WRONG: /Users/jimsander/repos, ~jimsander/.config
  - Rationale: Makes code portable across users and systems
- Function naming MUST follow: `<namespace>_<action>_<noun|description>` pattern
  - Examples: jira_create_link, gh_fetch_repo, eod_generate_report
- File existence checks MUST support symlinks: use -e instead of -f or -L
  - CORRECT: `[ -e "$file" ]` (works for regular files and symlinks)
  - WRONG: `[ -f "$file" ]` (fails on symlinks to files)
  - WRONG: `[ -L "$file" ]` (only detects symlinks, not regular files)
- Test resources:
  - Confluence test page: https://uniphore.atlassian.net/wiki/spaces/~63f5ec5740328c12e4ecdd02/pages/4356440111/Test+Page+Auto-updated+by+tests
  - Jira test ticket: https://uniphore.atlassian.net/browse/PANK-2134

## GNU Tools Requirement
- CRITICAL: ALWAYS use GNU tool variables in bash scripts, NEVER hardcoded commands
- Variables: $DATE (gdate), $SED (gsed), $GREP (ggrep), $AWK (gawk), $FIND (gfind), $XARGS (gxargs)
- These variables fallback to BSD versions when GNU not available, but scripts should be written for GNU first
- Example: Use `$DATE -d "5 days ago"` NOT `date -v-5d` (BSD-specific)
- Rationale: Cross-platform compatibility, consistent behavior across macOS and Linux
- Pattern for new scripts: Define tool variables at top, use throughout:
  ```bash
  DATE=$(command -v gdate || command -v date)
  SED=$(command -v gsed || command -v sed)
  # Then use $DATE, $SED everywhere
  ```

## Tool usage
- Prefer `rg` over `grep`.
- Use Task/Explore agents for open-ended searches (saves tokens vs running grep/read directly)
  - Use when: need multiple search attempts, exploring codebase structure, understanding how features work
  - Don't use when: exact file path known, searching 2-3 specific files
  - Specify thoroughness: "quick", "medium", "very thorough"
- Only create documentation files when explicitly requested.
- Use the Read tool before Write/Edit operations.

## GitHub repository analysis
- CRITICAL: Check ~/repos for locally cloned repos BEFORE making API calls
- For file history, workflow analysis, blame: use git commands on local clones (faster, no rate limits)
- Pattern: git -C ~/repos/<repo-name> log --follow -- <file-path>
- Only use gh api when repo is not available locally or for org-wide queries
- gh-helper functions may check local repos first (see QUICKREF.txt for available functions)

## Context Management & Caching
- MANDATORY PRE-FLIGHT CHECK before running any bash command:
  1. "Have I already run this or similar command in this conversation?"
  2. "If yes, did I cache the output to a file?"
  3. "If cached, STOP - use grep/head/tail on cached file instead"
  4. "For GitHub repo queries, is the repo cloned in ~/repos? If yes, use local git commands instead of API"
- ALWAYS cache command output when:
  - API responses that will be parsed multiple times
  - Long-running commands (eod_report, gh api, curl, kubectl)
  - ANY command whose output you might need to examine with different filters
- Pattern: Run command ONCE with output redirection (cmd > /tmp/cached-output.txt), then grep/head/tail the cached file
- Rationale: Each bash invocation + output costs ~600 tokens. Re-reading cached file costs ~50 tokens.
- VIOLATION: Re-running a command that could use cached output wastes 10-20x tokens
- Test file naming: test-claude-<purpose>.<ext> (automatically excluded from system reminders)
- Minimize repeated file reads - use grep/head/tail with line ranges instead of full Read when possible
- API calls (curl to Confluence, Jira): ALWAYS cache first response, use jq/grep on cached file for subsequent queries
- Avoid file redirection for: Unicode/UTF-8 output, single-shot display commands

## Image optimization
- Before reading images with Read tool, check file size: stat -f%z <file> (macOS) or stat -c%s <file> (Linux)
- If size > 5MB or dimensions > 2000px: create optimized version with ffmpeg, read optimized version instead
- Command: ffmpeg -i <input> -vf "scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease" -q:v 2 /tmp/<basename>_optimized.<ext>
- Supported formats: jpg, jpeg, png, webp

## Linting before file writes
- Before Write/Edit on code files, validate syntax:
  - Shell: shellcheck -x /tmp/shellcheck_$$.sh 2>&1 (show warnings, ask to proceed if errors)
  - Python: python3 -c "import ast; ast.parse(...)" or ruff check if available
  - JS/TS: eslint --stdin if available
- Skip linting when: user requests skip, files are WIP/draft, writing to /tmp/

## ASCII-only requirement
- Use only standard ASCII characters (0x20-0x7E) in all communication and code
- Use ASCII equivalents: -> instead of arrows, [!] for warnings, [OK] for success, [X] for errors
- Exception: widely-supported tools like tree command

## Session documentation
- Recognize phrases: "dump session", "save session notes", "summarize this session", "dump summary"
- **Automatic trigger**: At 50,000 token usage, proactively create session rollover document
- When user says "dump summary": Create ~/markdowns/eod-YYYY-MM-DD-<description>.md
  - Description: lowercase, hyphens, brief summary of topic (e.g., "tfc-aws-investigation", "jira-helper-pagination-fix")
  - Format: Comprehensive session summary with what was accomplished, files created, key findings
- When user says "rollover session": Create ~/markdowns/ROLLOVER_<topic>_<YYYYMMDDHHmm>.md
  - Topic: lowercase, hyphens only, POSIX-friendly (e.g., "pank-1485", "s3-bucket-fix")
  - Sections: Context, Changes, Decisions, Issues, Next steps
  - Format: markdown, concise, technical
- When auto-triggered at 50K tokens, notify user that rollover was created due to token threshold

## EOD one-off items
- When user says "add that to eod" or "add to today's eod" for work without a ticket
- Create entry in eod-YYYY-MM-DD-<descriptor>.md format
- Descriptor: lowercase, hyphens, brief (e.g., "writing-style-directive", "pr-template-fix")
- Format: Brief summary (2-3 bullets max), what was done, why it matters
- Keep it short, scannable, no ticket metadata needed

## Protected branch safety
- NEVER commit directly to main/master branches in repos 
- When git push fails with "repository rule violations":
  1. Check current branch: git branch --show-current
  2. If on main/master, create feature branch: git checkout -b <branch-name>
  3. Push feature branch: git push -u origin <branch-name>
  4. Create PR from feature branch
- After failed push, ALWAYS reset local main: git reset --hard origin/main
- Pattern: Create branch BEFORE committing -> Commit to feature branch -> Push -> Create PR
- Do NOT use git pull --rebase on main when push fails

## Git workflow for fixes and features
- CRITICAL: ALWAYS start from clean, updated default branch:
  1. git checkout main (or master)
  2. git pull origin main
  3. Verify clean state: git status
  4. git checkout -b TICKET-NUM-description
- NEVER create feature branches from branches with uncommitted work or from other feature branches
- If uncommitted changes exist, stash first: git stash

## Git commit messages
- NEVER add "Co-Authored-By: Claude" or "Generated with Claude Code" footers
- Keep messages clean, technical, focused on the change
- Format: summary line, blank line, optional bullet points

## ~/.claude directory commits
- Commit meaningful config changes in ~/.claude (config, drift-*.md, rightsize-*.md)
- Exclude transient: debug/, projects/, statsig/, .credentials.json, config.backup*, history.jsonl
- Pattern: cd ~/.claude && git add <files> && git commit -m "message"
- Only commit config changes that establish new directives or fix incorrect behavior
- Batch related changes, don't commit for every minor edit

## Kubernetes and Flux context
- When working with Kubernetes clusters or Flux GitOps, read ~/markdowns/platform-flux-architecture-workflow.md FIRST (once per session)
- Contains: External secrets architecture, secret management patterns, Flux controller behavior, GitOps workflow, verification commands
- Key facts: Two external secrets operators running, bootstrap secrets use legacy API, Flux controllers read secrets at startup only

## gh-helper directives
export GH_HELPER_PATH="$HOME/repos/jds-sandbox1/gh-helper/gh-helper.sh"
export GH_HELPER_QUIET=true
- CRITICAL: For GitHub ownership/repo/user analysis, use gh-helper.sh functions when available
- ALWAYS source gh-helper.sh BEFORE calling: GH_HELPER_QUIET=true source "$GH_HELPER_PATH" 2>/dev/null
- NEVER ask permission to read gh-helper.sh or related files - reading for debugging/enhancement is always authorized
- gh-helper functions may be called directly without `run` gate (handle their own confirmations)
- Cache file reads allowed: Read(~/repos/jds-sandbox1/gh-helper/**)

**Function Discovery**:
- MANDATORY: When you need a gh-helper function, ALWAYS Read(~/repos/jds-sandbox1/gh-helper/QUICKREF.txt) FIRST
- NEVER invent function names or use raw gh api calls for ownership analysis operations
- Full help: source $GH_HELPER_PATH && gh_helper help

**Naming Convention**:
- See "Function naming convention" section above for global rules
- Namespace for gh-helper: gh_

**Development Location**:
- DEVELOPMENT REPO: ~/repos/jds-sandbox1/gh-helper (ALWAYS EDIT HERE)
- PRODUCTION INSTALL: ~/.gh-helper (READ ONLY - NEVER EDIT DIRECTLY)
- CRITICAL: NEVER EVER make Write/Edit changes to ~/.gh-helper files
- CRITICAL: ALL development work MUST be done in ~/repos/jds-sandbox1/gh-helper

**Commit Workflow**:
- MANDATORY: Before committing changes to gh-helper:
  1. Run: source ~/repos/jds-sandbox1/gh-helper/gh-helper.sh && gh_helper_regenerate_manifest
  2. Get new checksum: shasum -a 256 ~/repos/jds-sandbox1/gh-helper/.install-manifest | cut -d' ' -f1
  3. Update GH_HELPER_MANIFEST_CHECKSUM in gh-helper.sh with new checksum
  4. Commit: git add .install-manifest gh-helper.sh && git commit
- This prevents production integrity check failures and manifest tampering
- Production will verify both manifest checksum and individual file checksums

## end gh-helper directives

## jira-helper directives
# WARNING: This section is auto-generated during jira-helper installation.
# Any manual edits will be overwritten on the next install/upgrade.
# To customize, edit ~/repos/jds-sandbox1/jira-helper/templates/claude-config-jira-helper.txt
export JIRA_HELPER_PATH="$HOME/.jira-helper/jira-helper.sh"
- CRITICAL: For Jira/Confluence, use jira-helper.sh functions when available
- ALWAYS source jira-helper.sh BEFORE calling: source "$JIRA_HELPER_PATH" 2>/dev/null
- NEVER ask permission to read jira-helper.sh or related files - reading for debugging/enhancement is always authorized
- NEVER modify ~/.jira (credentials). Only read from it
- jira-helper functions may be called directly without `run` gate (handle their own confirmations)
- Cache file reads allowed: Read(~/.jira-helper/**) and Read(~/.atlassian-cache/**)

**Function Discovery**:
- MANDATORY: When you need a jira-helper function, ALWAYS Read(~/.jira-helper/QUICKREF.txt) FIRST
- NEVER invent function names or use raw curl/API calls for Atlassian operations
- Full help: source ~/.jira-helper/jira-helper.sh && jira_helper help

**Confluence Content**:
- NEVER convert markdown to HTML before calling create_confluence_page
- Pass raw file content: create_confluence_page "PE" "Title" "$(cat file.md)"

**Platform Investigations workflow**:
- When user says "publish to platform investigations", "add to platform investigations", or similar:
  1. If markdown file is open/mentioned, use that file
  2. Extract ticket key from filename (pattern: TICKETKEY-*.md)
  3. Generate title from ticket key + file content (first H1 or descriptive title)
  4. Run: source ~/.jira-helper/jira-helper.sh && create_confluence_page "PE" "<title>" "$(cat <file>)" 4325900356
  5. Add Confluence link comment to Jira ticket
- Parent page ID for Platform Support Investigations: 4325900356
- Space key: PE (Product Engineering)
- Replace "Executive Summary" headers with "Background" or "High Level Summary" (more natural, less AI-sounding)

**EOD Reports workflow**:
- When user says "publish eod", "publish eod report", or similar:
  1. Generate report using: eod_report 7 confluence > /tmp/eod-report.md
  2. Extract date from report for title: "EOD Report - YYYY-MM-DD"
  3. Run: source ~/.jira-helper/jira-helper.sh && create_confluence_page "~63f5ec5740328c12e4ecdd02" "<title>" "$(cat /tmp/eod-report.md)" 4228939963
- Parent page ID for EOD Status Reports: 4228939963
- Space key: ~63f5ec5740328c12e4ecdd02 (Personal space)

**Session Auto-Poll**:
- At session start, proactively run: jira_check_awaiting_customer
- Shows customer response status, SLA breaches, auto-resumes blocked tickets
- Only run if session involves Jira work (use judgment)
- Keep output concise, summarize findings

**jq Requirement**: jira-helper requires jq >= 1.8. Use homebrew jq (/opt/homebrew/bin/jq), NOT anaconda jq

**Development Location**:
- DEVELOPMENT REPO: ~/repos/jds-sandbox1/jira-helper (ALWAYS EDIT HERE)
- PRODUCTION INSTALL: ~/.jira-helper (READ ONLY - NEVER EDIT DIRECTLY)
- CRITICAL: NEVER EVER make Write/Edit changes to ~/.jira-helper files
- CRITICAL: ALL development work MUST be done in ~/repos/jds-sandbox1/jira-helper

## end jira-helper directives
