#!/usr/bin/env bash
# Install jira-helper.sh for team use

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="${SCRIPT_DIR}/jira-helper.sh"
SOURCE_COMPLETION="${SCRIPT_DIR}/jira-helper-completion.sh"
SOURCE_WRAPPER="${SCRIPT_DIR}/jira-helper"
INSTALL_DIR="${HOME}/.jira-helper"
JIRA_HELPER_PATH="${INSTALL_DIR}/jira-helper.sh"
JIRA_HELPER_WRAPPER="${INSTALL_DIR}/jira-helper"
CACHE_DIR="${INSTALL_DIR}/.atlassian-cache"
CLAUDE_CONFIG="${HOME}/.claude/config"

echo "Installing jira-helper..."
echo "Source location: ${SCRIPT_DIR}"
echo "Install location: ${INSTALL_DIR}"

# Check jq version (>= 1.8 required for null coalescing operator //)
REQUIRED_JQ_MAJOR=1
REQUIRED_JQ_MINOR=8
JQ=$(command -v jq)
if [ -n "$JQ" ]; then
  jq_ver=$("$JQ" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  jq_major=$(echo "$jq_ver" | cut -d. -f1)
  jq_minor=$(echo "$jq_ver" | cut -d. -f2)
  if [ "$jq_major" -lt "$REQUIRED_JQ_MAJOR" ] || { [ "$jq_major" -eq "$REQUIRED_JQ_MAJOR" ] && [ "$jq_minor" -lt "$REQUIRED_JQ_MINOR" ]; }; then
    echo ""
    echo "ERROR: jq $jq_ver found but >= ${REQUIRED_JQ_MAJOR}.${REQUIRED_JQ_MINOR} required"
    echo "jira-helper uses the null coalescing operator (//) which requires jq 1.8+"
    echo ""
    echo "On macOS, ensure homebrew jq comes before anaconda jq in PATH:"
    echo "  brew install jq"
    echo "  # Add to ~/.bash_profile or ~/.zshrc:"
    echo "  export PATH=\"/opt/homebrew/bin:\$PATH\""
    exit 1
  fi
  echo "  jq version: $jq_ver (>= ${REQUIRED_JQ_MAJOR}.${REQUIRED_JQ_MINOR} required)"
else
  echo ""
  echo "ERROR: jq not found (required >= ${REQUIRED_JQ_MAJOR}.${REQUIRED_JQ_MINOR})"
  echo "Install with: brew install jq"
  exit 1
fi

# Check if jira-helper.sh exists
if [ ! -f "$SOURCE_SCRIPT" ]; then
  echo "ERROR: jira-helper.sh not found at ${SOURCE_SCRIPT}"
  exit 1
fi

# Check for required GNU tools
echo ""
echo "Checking for GNU tools..."
MISSING_TOOLS=()

# Check for gawk (required for fenced code block parsing)
if ! command -v gawk >/dev/null 2>&1; then
  if ! command -v awk >/dev/null 2>&1; then
    MISSING_TOOLS+=("gawk")
  else
    # Test if awk supports GNU-specific features
    if ! echo "test" | awk 'BEGIN {gsub(/test/, "ok")}' >/dev/null 2>&1; then
      MISSING_TOOLS+=("gawk (BSD awk lacks required features)")
    fi
  fi
fi

# Check for gsed (required for extended regex)
if ! command -v gsed >/dev/null 2>&1; then
  if ! command -v sed >/dev/null 2>&1; then
    MISSING_TOOLS+=("gsed")
  else
    # Test if sed supports extended regex properly
    if ! echo "test" | sed -E 's/test/ok/' >/dev/null 2>&1; then
      MISSING_TOOLS+=("gsed (BSD sed has limited regex support)")
    fi
  fi
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "[!] WARNING: Missing recommended GNU tools:"
  for tool in "${MISSING_TOOLS[@]}"; do
    echo "    - $tool"
  done
  echo ""
  echo "jira-helper will work with BSD tools for basic operations, but some features"
  echo "(like markdown conversion for Confluence) may not work correctly."
  echo ""
  echo "To install GNU coreutils on macOS:"
  echo "    brew install coreutils"
  echo ""
  read -p "Continue installation anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 1
  fi
else
  echo "  [OK] All required GNU tools found"
fi

# Create installation directory
echo "Creating installation directory..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CACHE_DIR"

# Copy files to installation directory
echo "Copying files..."
cp "$SOURCE_SCRIPT" "$JIRA_HELPER_PATH"
if [ -f "$SOURCE_COMPLETION" ]; then
  cp "$SOURCE_COMPLETION" "${INSTALL_DIR}/jira-helper-completion.sh"
  echo "  [OK] Copied jira-helper-completion.sh"
fi
if [ -f "$SOURCE_WRAPPER" ]; then
  cp "$SOURCE_WRAPPER" "$JIRA_HELPER_WRAPPER"
  echo "  [OK] Copied jira-helper wrapper"
fi
echo "  [OK] Copied jira-helper.sh"

# Make scripts executable
chmod +x "$JIRA_HELPER_PATH"
if [ -f "$JIRA_HELPER_WRAPPER" ]; then
  chmod +x "$JIRA_HELPER_WRAPPER"
fi
echo "  [OK] Made scripts executable"

# Capture version metadata from source repo
echo "Capturing version metadata..."
VERSION_FILE="${INSTALL_DIR}/VERSION"

# Find the git repo root (could be SCRIPT_DIR or parent)
GIT_ROOT=$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null || echo "")

if [ -n "$GIT_ROOT" ] && [ -d "${GIT_ROOT}/.git" ]; then
  cat > "$VERSION_FILE" <<EOF
JIRA_HELPER_VERSION=$(git -C "$GIT_ROOT" describe --tags --abbrev=0 2>/dev/null || echo 'unknown')
JIRA_HELPER_COMMIT=$(git -C "$GIT_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')
JIRA_HELPER_BRANCH=$(git -C "$GIT_ROOT" branch --show-current 2>/dev/null || echo 'detached')
JIRA_HELPER_SOURCE_DIR="${SCRIPT_DIR}"
JIRA_HELPER_GIT_ROOT="${GIT_ROOT}"
JIRA_HELPER_INSTALL_DATE="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
EOF
  echo "  [OK] Captured git version metadata"
else
  cat > "$VERSION_FILE" <<EOF
JIRA_HELPER_VERSION=unknown
JIRA_HELPER_COMMIT=unknown
JIRA_HELPER_BRANCH=unknown
JIRA_HELPER_SOURCE_DIR="${SCRIPT_DIR}"
JIRA_HELPER_GIT_ROOT=""
JIRA_HELPER_INSTALL_DATE="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
EOF
  echo "  [!] Source is not a git repo, version metadata limited"
fi

# Copy QUICKREF.txt for Claude Code discovery
if [ -f "${SCRIPT_DIR}/config/QUICKREF.txt" ]; then
  cp "${SCRIPT_DIR}/config/QUICKREF.txt" "${INSTALL_DIR}/QUICKREF.txt"
  echo "  [OK] Copied QUICKREF.txt"
else
  echo "  [!] WARNING: ${SCRIPT_DIR}/config/QUICKREF.txt not found"
fi

# Load Atlassian policy stanzas from config files
if [ -f "${SCRIPT_DIR}/config/ATLASSIAN_STANZA_MINIMAL.md" ]; then
  ATLASSIAN_STANZA_MINIMAL=$(cat "${SCRIPT_DIR}/config/ATLASSIAN_STANZA_MINIMAL.md")
else
  echo "ERROR: ${SCRIPT_DIR}/config/ATLASSIAN_STANZA_MINIMAL.md not found"
  exit 1
fi

if [ -f "${SCRIPT_DIR}/config/ATLASSIAN_STANZA_FULL.md" ]; then
  ATLASSIAN_STANZA_FULL=$(cat "${SCRIPT_DIR}/config/ATLASSIAN_STANZA_FULL.md")
else
  echo "ERROR: ${SCRIPT_DIR}/config/ATLASSIAN_STANZA_FULL.md not found"
  exit 1
fi

# Replace placeholders with actual paths
ATLASSIAN_STANZA_MINIMAL="${ATLASSIAN_STANZA_MINIMAL//%JIRA_HELPER_PATH%/${JIRA_HELPER_PATH}}"
ATLASSIAN_STANZA_FULL="${ATLASSIAN_STANZA_FULL//%JIRA_HELPER_PATH%/${JIRA_HELPER_PATH}}"
ATLASSIAN_STANZA_FULL="${ATLASSIAN_STANZA_FULL//%INSTALL_DIR%/${INSTALL_DIR}}"

# Check if .claude/config exists or if we're in Claude Code
if [ -f "$CLAUDE_CONFIG" ] || [ -n "$CLAUDECODE" ] || [ -n "$CLAUDE_CODE_SESSION" ] || [ -n "$ANTHROPIC_CLI" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Claude Code Configuration"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # Create .claude/config if it doesn't exist
  if [ ! -f "$CLAUDE_CONFIG" ]; then
    echo "No existing .claude/config found"
    echo ""
    read -p "Create .claude/config with jira-helper configuration? (y/N): " -r create_config
    echo ""
    if [[ ! $create_config =~ ^[Yy]$ ]]; then
      echo "Skipped - no changes to .claude/config"
      echo ""
    else
      echo "Creating ${CLAUDE_CONFIG}..."
      mkdir -p "$(dirname "$CLAUDE_CONFIG")"
      echo "# Claude Code Custom Instructions" > "$CLAUDE_CONFIG"
      echo "" >> "$CLAUDE_CONFIG"
    fi
  fi

  # Only proceed if config exists now (either already existed or was just created)
  if [ ! -f "$CLAUDE_CONFIG" ]; then
    # User declined to create config, skip to shell profile section
    :
  else

  # Check if the Atlassian policy stanza already exists
  if grep -q "## Atlassian policy" "$CLAUDE_CONFIG" 2>/dev/null; then
    # Check if config is already up-to-date by looking for key markers
    has_confluence_directive=$(grep -c "Confluence Content Format" "$CLAUDE_CONFIG" 2>/dev/null || true)
    has_function_discovery=$(grep -c "Function Discovery" "$CLAUDE_CONFIG" 2>/dev/null || true)
    has_correct_path=$(grep -c "JIRA_HELPER_PATH=\"${JIRA_HELPER_PATH}\"" "$CLAUDE_CONFIG" 2>/dev/null || true)

    # Default to 0 if empty
    has_confluence_directive=${has_confluence_directive:-0}
    has_function_discovery=${has_function_discovery:-0}
    has_correct_path=${has_correct_path:-0}

    # If all key markers present, config is up-to-date
    if [ "$has_confluence_directive" -gt 0 ] && [ "$has_function_discovery" -gt 0 ] && [ "$has_correct_path" -gt 0 ]; then
      echo "Found existing '## Atlassian policy' section in .claude/config"
      echo "[OK] Configuration is already up-to-date, skipping"
      echo ""
    else
      echo "Found existing '## Atlassian policy' section in .claude/config"
      echo ""
      echo "Options:"
      echo "  1) Update JIRA_HELPER_PATH only (keep your customizations)"
      echo "  2) Replace '## Atlassian policy' section with recommended config"
      echo "     (only affects .claude/config directives, not cache or credentials)"
      echo "  3) Skip (keep existing configuration as-is)"
      echo ""
      read -p "Choose [1-3]: " -r choice
      echo ""

    case "$choice" in
      1)
        # Update path only
        if grep -q "JIRA_HELPER_PATH=" "$CLAUDE_CONFIG" 2>/dev/null; then
          sed -i.bak "s|export JIRA_HELPER_PATH=.*|export JIRA_HELPER_PATH=\"${JIRA_HELPER_PATH}\"|" "$CLAUDE_CONFIG"
          echo "[OK] Updated JIRA_HELPER_PATH to: ${JIRA_HELPER_PATH}"
        else
          # Add JIRA_HELPER_PATH line after "## Atlassian policy"
          awk -v path="$JIRA_HELPER_PATH" '
            /## Atlassian policy/ {
              print
              print "export JIRA_HELPER_PATH=\"" path "\""
              next
            }
            {print}
          ' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp"
          mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"
          echo "[OK] Added JIRA_HELPER_PATH to existing section"
        fi
        ;;
      2)
        # Replace entire section
        # Remove old section (from ## Atlassian policy to next ## or end)
        awk '
          /## Atlassian policy/ { skip=1; next }
          /^## / && skip { skip=0 }
          !skip { print }
        ' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp"

        # Append new full stanza
        echo "" >> "${CLAUDE_CONFIG}.tmp"
        echo "$ATLASSIAN_STANZA_FULL" >> "${CLAUDE_CONFIG}.tmp"
        echo "" >> "${CLAUDE_CONFIG}.tmp"

        mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"
        echo "[OK] Replaced with recommended full configuration"
        ;;
      3|*)
        echo "Skipped - keeping existing configuration"
        ;;
    esac
    fi  # End of up-to-date check
  else
    # No existing section - prompt for minimal or full
    echo "No existing '## Atlassian policy' section found"
    echo ""
    echo "Install configuration:"
    echo "  1) Recommended full configuration (includes function list, workflows, etc.)"
    echo "  2) Minimal configuration (just the essentials)"
    echo "  3) Skip (don't add to .claude/config)"
    echo ""
    read -p "Choose [1-3]: " -r choice
    echo ""

    case "$choice" in
      1)
        echo "" >> "$CLAUDE_CONFIG"
        echo "$ATLASSIAN_STANZA_FULL" >> "$CLAUDE_CONFIG"
        echo "" >> "$CLAUDE_CONFIG"
        echo "[OK] Added recommended full Atlassian policy to ${CLAUDE_CONFIG}"
        ;;
      2)
        echo "" >> "$CLAUDE_CONFIG"
        echo "$ATLASSIAN_STANZA_MINIMAL" >> "$CLAUDE_CONFIG"
        echo "" >> "$CLAUDE_CONFIG"
        echo "[OK] Added minimal Atlassian policy to ${CLAUDE_CONFIG}"
        ;;
      3|*)
        echo "Skipped - no changes to .claude/config"
        ;;
    esac
  fi
  fi
else
  echo ""
  echo "No .claude/config found and not in Claude Code session"
  echo "To configure manually later, see: ${INSTALL_DIR}/README.md"
  echo ""
fi

# Add to shell profile for direct bash usage
for profile in ~/.bashrc ~/.bash_profile ~/.zshrc; do
  if [ -f "$profile" ]; then
    if ! grep -q "JIRA_HELPER_PATH" "$profile" 2>/dev/null; then
      echo "" >> "$profile"
      echo "# Atlassian jira-helper" >> "$profile"
      echo "export JIRA_HELPER_PATH=\"${JIRA_HELPER_PATH}\"" >> "$profile"
      echo "source \"\${JIRA_HELPER_PATH}\"" >> "$profile"
      echo "  [OK] Added to ${profile}"
    else
      echo "  [OK] Already configured in ${profile}"
    fi
  fi
done

echo ""
echo "=== Usage Tracking (Optional - 4 Week Pilot) ==="
echo ""
echo "Help improve jira-helper by enabling anonymous usage tracking."
echo ""
echo "What's tracked:"
echo "  - Function names (e.g., eod_report, jira_metrics_volume)"
echo "  - Timestamps and success/failure"
echo ""
echo "What's NOT tracked:"
echo "  - Ticket numbers, descriptions, or any Jira content"
echo "  - API tokens or credentials"
echo "  - Any personally identifiable information"
echo ""
echo "Data stays local on your machine at: ~/jira-helper/.usage-log"
echo "Auto-expires: 2025-12-06 (4 weeks)"
echo "View anytime: jira_helper_stats"
echo ""
read -p "Enable tracking? (y/N): " -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "export JIRA_HELPER_TRACK_USAGE=true  # Auto-expires 2025-12-06" >> ~/.bashrc
  echo "export JIRA_HELPER_TRACK_USAGE=true  # Auto-expires 2025-12-06" >> ~/.zshrc 2>/dev/null || true
  echo "[OK] Tracking enabled! Thank you for helping improve jira-helper."
  echo "  Opt out anytime: unset JIRA_HELPER_TRACK_USAGE"
else
  echo "Tracking not enabled. You can enable later with:"
  echo "  export JIRA_HELPER_TRACK_USAGE=true"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Installation complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installed to: ${INSTALL_DIR}"
echo "Cache directory: ${CACHE_DIR}"
echo ""

# Check for existing credentials
CREDENTIALS_VALID=false
if [ -f "${HOME}/.jira" ]; then
  echo "Checking existing Atlassian credentials..."
  # shellcheck source=/dev/null
  source "${HOME}/.jira" 2>/dev/null || true

  # Check if all required variables are set
  if [ -n "$ATLASSIAN_USER" ] && [ -n "$ATLASSIAN_API_TOKEN" ] && [ -n "$ATLASSIAN_DOCS" ] && [ -n "$ATLASSIAN_SITE_URL" ]; then
    # Test credentials with a simple API call
    if curl -s -u "${ATLASSIAN_USER}:${ATLASSIAN_API_TOKEN}" \
         "https://${ATLASSIAN_SITE_URL}/rest/api/3/myself" \
         -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "^200$"; then
      echo "[OK] Existing credentials are valid"
      echo "  User: ${ATLASSIAN_USER}"
      echo "  Site: ${ATLASSIAN_SITE_URL}"
      CREDENTIALS_VALID=true
    else
      echo "[X] Existing credentials found but API test failed"
      echo "  You may need to regenerate your API token"
    fi
  else
    echo "Found ~/.jira but missing required variables"
  fi
  echo ""
fi

echo "Next steps:"
if [ "$CREDENTIALS_VALID" = false ]; then
  echo "1. Set up Atlassian API credentials:"
  echo "   cd ${SCRIPT_DIR} && ./setup-credentials.sh"
else
  echo "1. [OK] Credentials already configured"
fi
echo ""
echo "2. Load jira-helper in your current shell:"
echo "   source ${JIRA_HELPER_PATH}"
echo ""
echo "   Or restart your shell to load automatically"
echo ""
echo "3. Test with:"
echo "   jh help"
echo "   jira_helper issues"
echo ""
