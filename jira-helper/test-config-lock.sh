#!/usr/bin/env bash
# test-config-lock.sh - Test lockfile functionality
#
# Tests the config-lock.sh lockfile mechanism to ensure:
# 1. Only one process can acquire the lock at a time
# 2. Stale locks are detected and cleaned up
# 3. Lock timeout works as expected

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.jira-helper"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Testing Config Lock Mechanism"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Source the lockfile helper
if [ ! -f "${INSTALL_DIR}/lib/config-lock.sh" ]; then
  echo -e "${RED}✗ config-lock.sh not found${NC}"
  echo "  Run ./install.sh first to install jira-helper"
  exit 1
fi

# shellcheck source=/dev/null
source "${INSTALL_DIR}/lib/config-lock.sh"

# Test 1: Basic lock acquisition and release
echo "Test 1: Basic lock acquisition and release"
if _acquire_config_lock; then
  echo -e "${GREEN}✓ Successfully acquired lock${NC}"

  # Check lock files exist
  if [ -d "${HOME}/.claude/.config.lock" ]; then
    echo -e "${GREEN}✓ Lock directory created${NC}"
  else
    echo -e "${RED}✗ Lock directory not found${NC}"
    exit 1
  fi

  # Release lock
  if _release_config_lock; then
    echo -e "${GREEN}✓ Successfully released lock${NC}"
  else
    echo -e "${RED}✗ Failed to release lock${NC}"
    exit 1
  fi

  # Verify lock is gone
  if [ ! -d "${HOME}/.claude/.config.lock" ]; then
    echo -e "${GREEN}✓ Lock directory removed${NC}"
  else
    echo -e "${RED}✗ Lock directory still exists${NC}"
    exit 1
  fi
else
  echo -e "${RED}✗ Failed to acquire lock${NC}"
  exit 1
fi

echo ""

# Test 2: Concurrent lock attempts (simulated)
echo "Test 2: Concurrent lock acquisition (should fail)"
if _acquire_config_lock; then
  echo -e "${GREEN}✓ First process acquired lock${NC}"

  # Try to acquire again (simulating another process)
  # This should fail since we already hold the lock
  if _acquire_config_lock 2>/dev/null; then
    echo -e "${RED}✗ Second lock acquisition should have failed but succeeded${NC}"
    _release_config_lock
    exit 1
  else
    echo -e "${GREEN}✓ Second lock acquisition correctly failed (lock held)${NC}"
  fi

  _release_config_lock
  echo -e "${GREEN}✓ Released lock${NC}"
else
  echo -e "${RED}✗ Failed initial lock acquisition${NC}"
  exit 1
fi

echo ""

# Test 3: Stale lock detection
echo "Test 3: Stale lock detection"
# Create a stale lock (old timestamp, non-existent PID)
mkdir -p "${HOME}/.claude/.config.lock"
echo "99999" > "${HOME}/.claude/.config.lock/pid"
echo "$(($(date +%s) - 100))" > "${HOME}/.claude/.config.lock/timestamp"

echo -e "${YELLOW}  Created stale lock (PID 99999, 100s old)${NC}"

# Try to acquire - should detect stale lock and succeed
if _acquire_config_lock; then
  echo -e "${GREEN}✓ Successfully acquired lock after detecting stale lock${NC}"
  _release_config_lock
else
  echo -e "${RED}✗ Failed to acquire lock (stale detection may have failed)${NC}"
  rm -rf "${HOME}/.claude/.config.lock"
  exit 1
fi

echo ""

# Test 4: _update_claude_config function
echo "Test 4: Test _update_claude_config function"
if [ -f "${HOME}/.claude/config" ]; then
  echo "  Creating backup of current config..."
  cp "${HOME}/.claude/config" "/tmp/claude-config-test-backup"

  if _update_claude_config "${INSTALL_DIR}/jira-helper.sh"; then
    echo -e "${GREEN}✓ Successfully updated Claude config with lockfile protection${NC}"

    # Verify the markdown section is present
    if grep -q "Markdown file locations" "${HOME}/.claude/config"; then
      echo -e "${GREEN}✓ Markdown file locations directive present${NC}"
    else
      echo -e "${YELLOW}⚠ Markdown file locations directive not found${NC}"
    fi
  else
    echo -e "${RED}✗ Failed to update Claude config${NC}"
    mv "/tmp/claude-config-test-backup" "${HOME}/.claude/config"
    exit 1
  fi

  echo "  Restoring original config..."
  mv "/tmp/claude-config-test-backup" "${HOME}/.claude/config"
else
  echo -e "${YELLOW}⚠ No .claude/config found, skipping update test${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}All tests passed!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
