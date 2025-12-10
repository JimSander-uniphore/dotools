# Markdown Conversion Test Document

This document tests all markdown features that jira-helper needs to convert correctly for Confluence.

## Headers

# H1 Header
## H2 Header
### H3 Header
#### H4 Header
##### H5 Header
###### H6 Header

## Text Formatting

**Bold text** using double asterisks
__Bold text__ using double underscores

*Italic text* using single asterisks
_Italic text_ using single underscores

`Inline code` using backticks

## Links

[Link text](https://example.com)
[GitHub](https://github.com)

## Lists

### Unordered Lists (Bullets)

- First item
- Second item
- Third item

* Item with asterisk
* Another asterisk item

### Ordered Lists

1. First item
2. Second item
3. Third item

## Code Blocks

### Fenced Code Block (No Language)

```
# This is a code block
function test() {
  echo "Hello"
}
```

### Fenced Code Block (With Language)

```bash
#!/bin/bash
# CODEOWNERS example
/.github/CODEOWNERS @team/platform
/.github/workflows/ @team/cicd
* @team/default
```

### Fenced Code Block with Special Characters

```
# Headers in code should not become <h1>
## These are comments
### Not HTML headers

<html>tags</html> should be escaped
& ampersands too
```

## Tables

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| Row 1 C1 | Row 1 C2 | Row 1 C3 |
| Row 2 C1 | Row 2 C2 | Row 2 C3 |

### Table with Alignment

| Left | Center | Right |
|:-----|:------:|------:|
| L1   | C1     | R1    |
| L2   | C2     | R2    |

## Mixed Content

This paragraph has **bold**, *italic*, and `code` inline.

Here's a list with code:
- Item with `inline code`
- Item with **bold text**
- Item with [link](https://example.com)

## Edge Cases

### Empty Lines

This paragraph is followed by multiple empty lines.



This paragraph comes after empty lines.

### Special Characters

- Ampersands: AT&T, R&D
- Less than / Greater than: 1 < 2, 3 > 1
- Quotes: "double quotes" and 'single quotes'

### Code Block After Header

### Header Immediately Before Code

```
This code block comes right after a header
with no blank line in between
```

## Real-World Example

```
# CODEOWNERS for platform-github-actions
# This file defines mandatory reviewers for critical infrastructure code

# Self-governance: CODEOWNERS changes require platform team approval
/.github/CODEOWNERS @uniphore/x-platform @uniphore/platform-cicd

# Critical deployment workflows (production impact)
/.github/workflows/cd.yml @uniphore/x-platform
/.github/workflows/single-tenant.yml @uniphore/x-platform

# Default: All other changes require platform-cicd review
* @uniphore/platform-cicd
```

Expected output: This code block should render as `<pre><code>...</code></pre>` with HTML-escaped content, NOT as headers and paragraphs.
