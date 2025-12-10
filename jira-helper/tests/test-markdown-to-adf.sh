#!/bin/bash
# Test markdown-to-ADF conversion to prevent regressions

# Load jira-helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../jira-helper.sh"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
  local test_name="$1"
  local markdown="$2"
  local expected_pattern="$3"

  echo "Testing: $test_name"

  local result
  result=$(_markdown_to_adf "$markdown")

  if echo "$result" | jq -e "$expected_pattern" > /dev/null 2>&1; then
    echo "  ✓ PASS"
    ((TESTS_PASSED++))
  else
    echo "  ✗ FAIL"
    echo "  Result: $result"
    ((TESTS_FAILED++))
  fi
}

echo "========================================"
echo "Markdown to ADF Conversion Tests"
echo "========================================"
echo ""

# Test 1: H1 heading (should be stripped)
run_test "H1 heading stripped" \
  "# Title" \
  '.content | length == 0'

# Test 2: H2 heading
run_test "H2 heading" \
  "## Heading 2" \
  '.content[0].type == "heading" and .content[0].attrs.level == 2'

# Test 3: H3 heading
run_test "H3 heading" \
  "### Heading 3" \
  '.content[0].type == "heading" and .content[0].attrs.level == 3'

# Test 4: H4 heading
run_test "H4 heading" \
  "#### Heading 4" \
  '.content[0].type == "heading" and .content[0].attrs.level == 4'

# Test 5: H5 heading
run_test "H5 heading" \
  "##### Heading 5" \
  '.content[0].type == "heading" and .content[0].attrs.level == 5'

# Test 6: H6 heading
run_test "H6 heading" \
  "###### Heading 6" \
  '.content[0].type == "heading" and .content[0].attrs.level == 6'

# Test 7: Code block with language
run_test "Code block with language" \
  '```yaml
key: value
```' \
  '.content[0].type == "codeBlock" and .content[0].attrs.language == "yaml"'

# Test 8: Code block without language
run_test "Code block without language" \
  '```
plain text
```' \
  '.content[0].type == "codeBlock"'

# Test 9: TOC macro
run_test "TOC macro" \
  "[Confluence TOC Macro]" \
  '.content[0].type == "extension" and .content[0].attrs.extensionKey == "toc"'

# Test 10: Info panel
run_test "Info panel" \
  "[Confluence Info Panel]

Test content

[/Info Panel]" \
  '.content[0].type == "panel" and .content[0].attrs.panelType == "info"'

# Test 11: Bullet list
run_test "Bullet list" \
  "- Item 1
- Item 2" \
  '.content[0].type == "bulletList"'

# Test 12: Paragraph with bold
run_test "Bold text" \
  "This is **bold** text" \
  '.content[0].type == "paragraph" and (.content[0].content | map(select(.marks[]?.type == "strong")) | length > 0)'

# Test 13: Paragraph with inline code
run_test "Inline code" \
  "This is \`code\` text" \
  '.content[0].type == "paragraph" and (.content[0].content | map(select(.marks[]?.type == "code")) | length > 0)'

# Test 14: JIRA reference (should be converted to plain text)
run_test "JIRA reference" \
  "[JIRA:PANK-1485]" \
  '.content[0].type == "paragraph" and .content[0].content[0].text == "PANK-1485"'

echo ""
echo "========================================"
echo "Test Results"
echo "========================================"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ Some tests failed"
  exit 1
fi
