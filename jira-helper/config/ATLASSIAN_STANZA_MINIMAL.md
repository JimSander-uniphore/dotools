## Atlassian policy
export JIRA_HELPER_PATH="%JIRA_HELPER_PATH%"
- CRITICAL: For Jira/Confluence, use jira-helper.sh functions when available.
- ALWAYS source jira-helper.sh using: source "$JIRA_HELPER_PATH"
- Do not hand-roll curl for Atlassian if a jira-helper function exists.
- Read-only helpers (local cache reads) may run without `run`.
- Any operation that hits the network or changes state requires `run`.
