#!/usr/bin/env bash
# markdown-to-adf.sh - Markdown to ADF (Atlassian Document Format) conversion
#
# This module provides comprehensive markdown-to-ADF conversion for Jira comments.
# Handles: paragraphs, headings, bullet lists, tables, code blocks, inline formatting

_text_to_adf_paragraphs() {
  local text="$1"
  local paragraphs="[]"
  local in_list=false
  local list_items="[]"
  local in_code_block=false
  local code_buffer=""
  local code_language=""
  local in_table=false
  local table_rows="[]"
  local is_header_row=true

  # Split by newlines and process each line
  while IFS= read -r line; do
    # Check for code fence (opening or closing)
    if [[ "$line" =~ ^\`\`\`(.*)$ ]]; then
      if [ "$in_code_block" = false ]; then
        # Opening fence - close any open list/table first
        if [ "$in_table" = true ]; then
          paragraphs=$(echo "$paragraphs" | jq --argjson rows "$table_rows" '. += [{"type": "table", "content": $rows}]')
          table_rows="[]"
          in_table=false
          is_header_row=true
        fi
        if [ "$in_list" = true ]; then
          paragraphs=$(echo "$paragraphs" | jq --argjson items "$list_items" '. += [{"type": "bulletList", "content": $items}]')
          list_items="[]"
          in_list=false
        fi

        in_code_block=true
        code_language="${BASH_REMATCH[1]}"
        code_buffer=""
      else
        # Closing fence - output code block
        local code_text="$code_buffer"
        if [ -n "$code_language" ]; then
          paragraphs=$(echo "$paragraphs" | jq --arg lang "$code_language" --arg text "$code_text" \
            '. += [{"type": "codeBlock", "attrs": {"language": $lang}, "content": [{"type": "text", "text": $text}]}]')
        else
          paragraphs=$(echo "$paragraphs" | jq --arg text "$code_text" \
            '. += [{"type": "codeBlock", "content": [{"type": "text", "text": $text}]}]')
        fi
        in_code_block=false
        code_language=""
        code_buffer=""
      fi
      continue
    fi

    # If inside code block, buffer the line
    if [ "$in_code_block" = true ]; then
      if [ -z "$code_buffer" ]; then
        code_buffer="$line"
      else
        code_buffer="$code_buffer"$'\n'"$line"
      fi
      continue
    fi

    if [ -n "$line" ]; then
      # Check if line is a table row (contains |)
      if [[ "$line" =~ \| ]]; then
        # Skip separator rows (like |---|---|)
        if [[ "$line" =~ ^\|?[[:space:]]*[-:]+[[:space:]]*\|[[:space:]]*[-:]+[[:space:]]*\|?.*$ ]]; then
          is_header_row=false
          continue
        fi

        # Close any open list before starting table
        if [ "$in_list" = true ]; then
          paragraphs=$(echo "$paragraphs" | jq --argjson items "$list_items" '. += [{"type": "bulletList", "content": $items}]')
          list_items="[]"
          in_list=false
        fi

        # Parse table cells
        line="${line#|}"
        line="${line%|}"

        local IFS='|'
        read -ra cells <<< "$line"

        local row_cells="[]"
        local cell_type="tableHeader"
        if [ "$in_table" = true ] && [ "$is_header_row" = false ]; then
          cell_type="tableCell"
        fi

        for cell in "${cells[@]}"; do
          # Trim whitespace
          cell="${cell#"${cell%%[![:space:]]*}"}"
          cell="${cell%"${cell##*[![:space:]]}"}"

          local content=$(_text_to_adf_with_markdown "$cell")
          row_cells=$(echo "$row_cells" | jq --arg type "$cell_type" --argjson content "$content" '. += [{"type": $type, "content": [{"type": "paragraph", "content": $content}]}]')
        done

        table_rows=$(echo "$table_rows" | jq --argjson cells "$row_cells" '. += [{"type": "tableRow", "content": $cells}]')
        in_table=true

      # Check if line is a bullet point (starts with - or * followed by space)
      elif [[ "$line" =~ ^[[:space:]]*[-\*][[:space:]].* ]]; then
        # Close any open table before starting list
        if [ "$in_table" = true ]; then
          paragraphs=$(echo "$paragraphs" | jq --argjson rows "$table_rows" '. += [{"type": "table", "content": $rows}]')
          table_rows="[]"
          in_table=false
          is_header_row=true
        fi

        # Extract the content after the bullet marker
        local bullet_text="${line#"${line%%[-\*]*}"}"  # Remove leading whitespace
        bullet_text="${bullet_text#[-\*]}"  # Remove bullet marker
        bullet_text="${bullet_text#"${bullet_text%%[! ]*}"}"  # Remove leading spaces after marker

        local content=$(_text_to_adf_with_markdown "$bullet_text")
        list_items=$(echo "$list_items" | jq --argjson content "$content" '. += [{"type": "listItem", "content": [{"type": "paragraph", "content": $content}]}]')
        in_list=true
      else
        # Not a bullet point or table row - close any open table first
        if [ "$in_table" = true ]; then
          paragraphs=$(echo "$paragraphs" | jq --argjson rows "$table_rows" '. += [{"type": "table", "content": $rows}]')
          table_rows="[]"
          in_table=false
          is_header_row=true
        fi

        # If we were in a list, close it
        if [ "$in_list" = true ]; then
          paragraphs=$(echo "$paragraphs" | jq --argjson items "$list_items" '. += [{"type": "bulletList", "content": $items}]')
          list_items="[]"
          in_list=false
        fi

        # Check if line is a header (starts with # through ######)
        if [[ "$line" =~ ^(#{1,6})[[:space:]]+(.*) ]]; then
          local header_level="${#BASH_REMATCH[1]}"
          local header_text="${BASH_REMATCH[2]}"
          local content=$(_text_to_adf_with_markdown "$header_text")
          paragraphs=$(echo "$paragraphs" | jq --argjson content "$content" --argjson level "$header_level" '. += [{"type": "heading", "attrs": {"level": $level}, "content": $content}]')
        else
          # Add as regular paragraph
          local content=$(_text_to_adf_with_markdown "$line")
          paragraphs=$(echo "$paragraphs" | jq --argjson content "$content" '. += [{"type": "paragraph", "content": $content}]')
        fi
      fi
    fi
  done <<< "$text"

  # Close any remaining code block at the end (unclosed fence)
  if [ "$in_code_block" = true ]; then
    local code_text="$code_buffer"
    if [ -n "$code_language" ]; then
      paragraphs=$(echo "$paragraphs" | jq --arg lang "$code_language" --arg text "$code_text" \
        '. += [{"type": "codeBlock", "attrs": {"language": $lang}, "content": [{"type": "text", "text": $text}]}]')
    else
      paragraphs=$(echo "$paragraphs" | jq --arg text "$code_text" \
        '. += [{"type": "codeBlock", "content": [{"type": "text", "text": $text}]}]')
    fi
  fi

  # Close any remaining table at the end
  if [ "$in_table" = true ]; then
    paragraphs=$(echo "$paragraphs" | jq --argjson rows "$table_rows" '. += [{"type": "table", "content": $rows}]')
  fi

  # Close any remaining list at the end
  if [ "$in_list" = true ]; then
    paragraphs=$(echo "$paragraphs" | jq --argjson items "$list_items" '. += [{"type": "bulletList", "content": $items}]')
  fi

  echo "$paragraphs"
}

# Convert markdown to full ADF document format
# Usage: _markdown_to_adf <markdown_text>
# Returns: Complete ADF document as JSON string
_markdown_to_adf() {
  local markdown="$1"

  # Preprocess: Strip first H1 heading (redundant with page title)
  # Remove lines like "# Title" at the start of the document
  markdown=$(echo "$markdown" | sed '1{/^# /d;}')

  # Preprocess Confluence macros - replace with special markers that will be converted to ADF
  # Handle [Confluence TOC Macro]
  markdown=$(echo "$markdown" | sed 's/\[Confluence TOC Macro\]/__CONFLUENCE_TOC__/g')

  # Handle [Confluence Info Panel] ... [/Info Panel]
  markdown=$(echo "$markdown" | perl -0777 -pe 's/\[Confluence Info Panel\]\n\n(.*?)\n\n\[\/Info Panel\]/__CONFLUENCE_INFO_START__\n\1\n__CONFLUENCE_INFO_END__/gs')

  # Handle [JIRA:KEY-123] - convert to plain text for now (ADF doesn't have native JIRA macro)
  markdown=$(echo "$markdown" | sed -E 's/\[JIRA:([A-Z]+-[0-9]+)\]/\1/g')

  # Convert markdown to ADF content array
  local content_array
  content_array=$(_text_to_adf_paragraphs "$markdown")

  # Post-process: Replace special markers with actual ADF macro nodes
  # Add TOC extension nodes
  content_array=$(echo "$content_array" | jq '
    map(
      if .type == "paragraph" and (.content[0].text? // "") == "__CONFLUENCE_TOC__" then
        {
          type: "extension",
          attrs: {
            layout: "default",
            extensionType: "com.atlassian.confluence.macro.core",
            extensionKey: "toc",
            parameters: {
              macroParams: {
                minLevel: {value: "1"},
                maxLevel: {value: "3"},
                outline: {value: "false"},
                style: {value: "none"},
                type: {value: "list"},
                printable: {value: "true"}
              },
              macroMetadata: {
                schemaVersion: {value: "1"},
                title: "Table of Contents"
              }
            },
            localId: (now | tostring)
          }
        }
      else
        .
      end
    )
  ')

  # Handle info panels - find __CONFLUENCE_INFO_START__ and __CONFLUENCE_INFO_END__ markers
  # Collect content between markers into a panel node
  content_array=$(echo "$content_array" | jq '
    reduce .[] as $item (
      {result: [], inPanel: false, panelContent: []};
      if $item.type == "paragraph" and ($item.content[0].text? // "") == "__CONFLUENCE_INFO_START__" then
        {result: .result, inPanel: true, panelContent: []}
      elif $item.type == "paragraph" and ($item.content[0].text? // "") == "__CONFLUENCE_INFO_END__" then
        {
          result: (.result + [{
            type: "panel",
            attrs: {panelType: "info"},
            content: .panelContent
          }]),
          inPanel: false,
          panelContent: []
        }
      elif .inPanel then
        {result: .result, inPanel: true, panelContent: (.panelContent + [$item])}
      else
        {result: (.result + [$item]), inPanel: .inPanel, panelContent: .panelContent}
      end
    ) | .result
  ')

  # Wrap in ADF document structure
  echo "$content_array" | jq '{
    type: "doc",
    version: 1,
    content: .
  }'
}

# Helper function: Convert plain text with URLs to ADF content nodes
# URLs are detected and converted to clickable links
_text_to_adf_with_links() {
  local text="$1"
  local result="[]"

  # URL regex pattern (simplified but catches most URLs)
  local url_pattern='https?://[^[:space:])>]+'

  # Split text by URLs and build ADF nodes
  local remaining="$text"
  local first_node=true

  while [[ "$remaining" =~ $url_pattern ]]; do
    local url="${BASH_REMATCH[0]}"
    local before="${remaining%%"$url"*}"
    local after="${remaining#*"$url"}"

    # Add text before URL (if any)
    if [ -n "$before" ]; then
      if [ "$first_node" = true ]; then
        result=$(echo "$result" | jq --arg text "$before" '. += [{"type": "text", "text": $text}]')
        first_node=false
      else
        result=$(echo "$result" | jq --arg text "$before" '. += [{"type": "text", "text": $text}]')
      fi
    fi

    # Add URL as link
    result=$(echo "$result" | jq --arg url "$url" '. += [{"type": "text", "text": $url, "marks": [{"type": "link", "attrs": {"href": $url}}]}]')
    first_node=false

    remaining="$after"
  done

  # Add any remaining text after last URL
  if [ -n "$remaining" ]; then
    if [ "$first_node" = true ]; then
      # No URLs found, just plain text
      result='[{"type": "text", "text": "'"${remaining}"'"}]'
    else
      result=$(echo "$result" | jq --arg text "$remaining" '. += [{"type": "text", "text": $text}]')
    fi
  fi

  echo "$result"
}

# Helper function: Convert text with markdown formatting to ADF content nodes
# Handles: **bold**, `code`, and URLs
_text_to_adf_with_markdown() {
  local text="$1"
  local result="[]"

  # Process text for markdown patterns: **bold**, `code`, URLs
  local remaining="$text"

  while [ -n "$remaining" ]; do
    local matched=false

    # Try to match **bold** (non-greedy)
    if [[ "$remaining" =~ \*\*([^*]+)\*\* ]]; then
      local full_match="${BASH_REMATCH[0]}"
      local bold_text="${BASH_REMATCH[1]}"
      local before="${remaining%%"$full_match"*}"
      local after="${remaining#*"$full_match"}"

      # Add text before bold
      if [ -n "$before" ]; then
        result=$(echo "$result" | jq --arg text "$before" '. += [{"type": "text", "text": $text}]')
      fi

      # Add bold text
      result=$(echo "$result" | jq --arg text "$bold_text" '. += [{"type": "text", "text": $text, "marks": [{"type": "strong"}]}]')
      remaining="$after"
      matched=true

    # Try to match `code`
    elif [[ "$remaining" =~ \`([^\`]+)\` ]]; then
      local full_match="${BASH_REMATCH[0]}"
      local code_text="${BASH_REMATCH[1]}"
      local before="${remaining%%"$full_match"*}"
      local after="${remaining#*"$full_match"}"

      # Add text before code
      if [ -n "$before" ]; then
        result=$(echo "$result" | jq --arg text "$before" '. += [{"type": "text", "text": $text}]')
      fi

      # Add code text
      result=$(echo "$result" | jq --arg text "$code_text" '. += [{"type": "text", "text": $text, "marks": [{"type": "code"}]}]')
      remaining="$after"
      matched=true

    # Try to match URLs
    elif [[ "$remaining" =~ https?://[^[:space:]\)\>]+ ]]; then
      local url="${BASH_REMATCH[0]}"
      local before="${remaining%%"$url"*}"
      local after="${remaining#*"$url"}"

      # Add text before URL
      if [ -n "$before" ]; then
        result=$(echo "$result" | jq --arg text "$before" '. += [{"type": "text", "text": $text}]')
      fi

      # Add URL as link
      result=$(echo "$result" | jq --arg url "$url" '. += [{"type": "text", "text": $url, "marks": [{"type": "link", "attrs": {"href": $url}}]}]')
      remaining="$after"
      matched=true
    fi

    # If nothing matched, add remaining text and break
    if [ "$matched" = false ]; then
      if [ -n "$remaining" ]; then
        result=$(echo "$result" | jq --arg text "$remaining" '. += [{"type": "text", "text": $text}]')
      fi
      break
    fi
  done

  # Handle empty result
  if [ "$result" = "[]" ]; then
    result='[{"type": "text", "text": ""}]'
  fi

  echo "$result"
}
