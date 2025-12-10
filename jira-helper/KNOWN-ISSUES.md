# Known Issues and Bugs

Tracking bugs and issues in jira-helper v1.0.

## ADF Converter - Fenced Code Blocks Not Supported

**Status:** Open
**Severity:** High
**Version:** v1.0.0-rc1

**Issue:**
Markdown to ADF conversion does NOT support fenced code blocks (triple backticks) at all. The `_text_to_adf_paragraphs()` function processes text line-by-line and has no state tracking for multi-line code blocks.

**Symptoms:**
- Fenced code blocks (with or without language specifiers) render as plain text in Jira comments
- Opening/closing backtick fences (```` ``` ````) appear as literal text
- No code block formatting applied
- Multi-line code loses formatting entirely

**Example:**
```markdown
Configuration example:

```
foo: bar
baz: qux
```

Also fails with language specifiers:

```yaml
foo: bar
baz: qux
```
```

**Expected:** Code block with monospace font in gray box (standard ADF code block)
**Actual:** Plain text paragraphs with visible backtick fences

**Affected Functions:**
- `_text_to_adf_paragraphs()` (line 2188+ in jira-helper.sh) - Line-by-line processing, no multi-line state
- `_text_to_adf_with_markdown()` (line 2286+) - Only handles inline code (single backticks)

**Root Cause:**
Jira-helper has TWO separate markdown converters:
1. **HTML converter** (for Confluence pages) - at line 2392+, DOES support fenced code blocks
2. **ADF converter** (for Jira comments) - at line 2188+, does NOT support fenced code blocks

The ADF converter was designed for simple inline formatting (bold, links, inline code). Multi-line constructs (tables) were added later, but fenced code blocks were never implemented. The HTML converter's code block logic (lines 2392-2426) needs to be ported to ADF format

**Workaround:**
None effective. Inline code with `backticks` works for short snippets but multi-line code cannot be properly formatted.

**Fix Required:**
Add fenced code block support to `_text_to_adf_paragraphs()`:
1. Detect opening fence: `/^```(.*)$/` (with optional language capture)
2. Track `in_code_block` state like `in_table` and `in_list`
3. Buffer code lines
4. On closing fence, output ADF structure:
   ```json
   {
     "type": "codeBlock",
     "attrs": {"language": "yaml"},
     "content": [{"type": "text", "text": "buffered code"}]
   }
   ```
5. Handle language specifiers (yaml, bash, python, etc.)

**Priority:** High - blocks proper documentation and technical content in Jira comments

---

## Contributing

Found a bug? Add it to this file using the format:

```markdown
## Brief Bug Title

**Status:** Open / In Progress / Fixed
**Severity:** Low / Medium / High / Critical
**Version:** vX.Y.Z

**Issue:** Clear description

**Symptoms:** What users observe

**Example:** Reproduction case

**Expected:** What should happen
**Actual:** What actually happens

**Affected Functions:** Function names and line numbers

**Root Cause:** Technical explanation (if known)

**Workaround:** Temporary solution (if available)

**Fix Required:** What needs to change

**Priority:** Ranking with rationale
```
