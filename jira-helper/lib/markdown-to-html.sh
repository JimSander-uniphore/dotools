#!/usr/bin/env bash
# markdown-to-html.sh - Markdown to HTML conversion for Confluence
#
# This module provides markdown-to-HTML conversion for Confluence pages.
# Handles: code blocks, tables, headings, lists, inline formatting, links

# Convert markdown content to HTML
# Usage: _markdown_to_html "markdown content"
# Returns: HTML string
_markdown_to_html() {
  local content="$1"

  # Enhanced markdown to HTML conversion
  # Process in stages to avoid conflicts between patterns

  # Stage 0: Fenced code blocks (```...```) - must come first to protect content
  content=$(echo "$content" | "$AWK" '
    BEGIN { in_code = 0; code_buffer = "" }
    /^```/ {
      if (in_code == 0) {
        # Start of code block
        in_code = 1
        code_buffer = ""
      } else {
        # End of code block - output buffered content on single line with <br/> tags
        printf "<pre><code>%s</code></pre>\n", code_buffer
        in_code = 0
        code_buffer = ""
      }
      next
    }
    in_code == 1 {
      # Inside code block - HTML escape special characters and buffer
      line = $0
      gsub(/&/, "\\&amp;", line)
      gsub(/</, "\\&lt;", line)
      gsub(/>/, "\\&gt;", line)
      # Append to buffer with <br/> separator (but not before first line)
      if (code_buffer == "") {
        code_buffer = line
      } else {
        code_buffer = code_buffer "<br/>" line
      }
      next
    }
    {
      # Outside code block - pass through for further processing
      print
    }
  ')

  # Stage 0.5: Tables (|...| format) - must come after code blocks, before other conversions
  content=$(echo "$content" | "$AWK" '
    BEGIN { in_table = 0; table_html = ""; is_first_row = 1 }
    /^\|.*\|$/ {
      # Check if this is a separator row (contains only |, -, :, and whitespace)
      if ($0 ~ /^\|[-: \t|]+\|$/) {
        # Separator row - skip it
        next
      }

      if (in_table == 0) {
        # Start of table
        in_table = 1
        is_first_row = 1
        table_html = "<table><tbody>"
      }

      # Parse row (header or data)
      line = $0
      gsub(/^\|[ \t]*/, "", line)
      gsub(/[ \t]*\|$/, "", line)
      split(line, cells, /[ \t]*\|[ \t]*/)

      if (is_first_row == 1) {
        # First row is header
        table_html = table_html "<tr>"
        for (i = 1; i <= length(cells); i++) {
          table_html = table_html "<th>" cells[i] "</th>"
        }
        table_html = table_html "</tr>"
        is_first_row = 0
      } else {
        # Subsequent rows are data
        table_html = table_html "<tr>"
        for (i = 1; i <= length(cells); i++) {
          table_html = table_html "<td>" cells[i] "</td>"
        }
        table_html = table_html "</tr>"
      }
      next
    }
    in_table == 1 {
      # End of table (non-table line encountered)
      table_html = table_html "</tbody></table>"
      print table_html
      table_html = ""
      in_table = 0
      is_first_row = 1
      print
      next
    }
    {
      print
    }
    END {
      if (in_table == 1) {
        # Close table at end of input
        table_html = table_html "</tbody></table>"
        print table_html
      }
    }
  ')

  # Stage 1: Headings (# through ######)
  content=$(echo "$content" | "$SED" -E '
    s/^###### (.+)$/<h6>\1<\/h6>/
    s/^##### (.+)$/<h5>\1<\/h5>/
    s/^#### (.+)$/<h4>\1<\/h4>/
    s/^### (.+)$/<h3>\1<\/h3>/
    s/^## (.+)$/<h2>\1<\/h2>/
    s/^# (.+)$/<h1>\1<\/h1>/
  ')

  # Stage 2: Lists (unordered)
  content=$(echo "$content" | "$AWK" '
    BEGIN { in_list = 0 }
    /^[-*] / {
      if (in_list == 0) {
        print "<ul>"
        in_list = 1
      }
      sub(/^[-*] /, "")
      print "<li>" $0 "</li>"
      next
    }
    in_list == 1 {
      print "</ul>"
      in_list = 0
    }
    { print }
    END {
      if (in_list == 1) {
        print "</ul>"
      }
    }
  ')

  # Stage 3: Inline formatting (bold, italic, code, links)
  # Bold: **text** or __text__
  content=$(echo "$content" | "$SED" -E '
    s/\*\*([^*]+)\*\*/<strong>\1<\/strong>/g
    s/__([^_]+)__/<strong>\1<\/strong>/g
  ')

  # Italic: *text* or _text_ (but not ** or __)
  content=$(echo "$content" | "$SED" -E '
    s/([^*])\*([^*]+)\*([^*])/\1<em>\2<\/em>\3/g
    s/([^_])_([^_]+)_([^_])/\1<em>\2<\/em>\3/g
  ')

  # Inline code: `code`
  content=$(echo "$content" | "$SED" -E 's/`([^`]+)`/<code>\1<\/code>/g')

  # Links: [text](url)
  content=$(echo "$content" | "$SED" -E 's/\[([^\]]+)\]\(([^)]+)\)/<a href="\2">\1<\/a>/g')

  # Stage 4: Paragraphs (wrap non-tagged lines)
  content=$(echo "$content" | "$AWK" '
    BEGIN { in_para = 0 }
    /^$/ {
      if (in_para == 1) {
        print "</p>"
        in_para = 0
      }
      print
      next
    }
    /^<(h[1-6]|ul|ol|li|pre|table|code|div)/ {
      if (in_para == 1) {
        print "</p>"
        in_para = 0
      }
      print
      next
    }
    /^<\/(ul|ol|table|pre|div)>/ {
      print
      next
    }
    {
      if (in_para == 0) {
        printf "<p>"
        in_para = 1
      }
      print
    }
    END {
      if (in_para == 1) {
        print "</p>"
      }
    }
  ')

  echo "$content"
}

# Detect if content looks like markdown (not HTML)
# Usage: _is_markdown "content"
# Returns: 0 if markdown, 1 if HTML
_is_markdown() {
  local content="$1"

  # Check for markdown markers first (most reliable)
  if echo "$content" | grep -qE '^#{1,6} |^[-*] |\*\*|__|\[.*\]\(|^\|.*\|'; then
    return 0  # Has markdown markers
  fi

  # Check for actual HTML tags (not placeholders like <TAB> or <your-repo>)
  # Look for common HTML tags with proper structure
  if echo "$content" | grep -qE '<(p|div|table|tr|td|th|ul|ol|li|h[1-6]|pre|code|span|strong|em|a)[> ]'; then
    return 1  # Has HTML tags
  fi

  # Default: treat as markdown if ambiguous
  return 0
}
