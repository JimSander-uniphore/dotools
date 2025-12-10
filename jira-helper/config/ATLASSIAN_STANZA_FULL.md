## Atlassian policy
export JIRA_HELPER_PATH="%JIRA_HELPER_PATH%"
- CRITICAL: For Jira/Confluence, use jira-helper.sh functions when available
- ALWAYS source jira-helper.sh BEFORE calling: source "$JIRA_HELPER_PATH" 2>/dev/null
- NEVER modify ~/.jira (credentials). Only read from it
- jira-helper functions may be called directly without `run` gate (handle their own confirmations)
- Cache file reads allowed: Read(%INSTALL_DIR%/**) and Read(%INSTALL_DIR%/.atlassian-cache/**)

**Function Discovery**:
- MANDATORY: When you need a jira-helper function, ALWAYS Read(%INSTALL_DIR%/QUICKREF.txt) FIRST
- NEVER invent function names or use raw curl/API calls for Atlassian operations
- Full help: source ~/.jira-helper/jira-helper.sh && jira_helper help

**Confluence Content**:
- NEVER convert markdown to HTML before calling create_confluence_page
- Pass raw file content: create_confluence_page "PE" "Title" "$(cat file.md)"

**jq Requirement**: jira-helper requires jq >= 1.8. Use homebrew jq (/opt/homebrew/bin/jq), NOT anaconda jq
