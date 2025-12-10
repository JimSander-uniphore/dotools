#!/usr/bin/env bash
# adf-to-markdown.sh - Atlassian Document Format (ADF) to Markdown converter
#
# This module converts ADF JSON to clean Markdown text.
# ADF is used by Jira Cloud and Confluence Cloud for rich text content.

# Convert ADF JSON to Markdown
# Usage: _adf_to_markdown '{"type":"doc","content":[...]}'
# Returns: Markdown string
_adf_to_markdown() {
  local adf_json="$1"

  if [ -z "$adf_json" ] || [ "$adf_json" = "null" ]; then
    echo ""
    return 0
  fi

  # Use jq to recursively process ADF nodes and convert to markdown
  # Note: Single recursive function to avoid jq forward reference issues
  echo "$adf_json" | jq -r '
    def process:
      if type == "array" then
        map(process) | join("")
      elif type != "object" then
        tostring
      elif .type == "doc" then
        [.content[]? | process] | join("\n\n")
      elif .type == "paragraph" then
        [.content[]? | process] | join("")
      elif .type == "text" then
        # Apply marks (bold, italic, code, etc.)
        .text as $text |
        if .marks then
          .marks | reduce .[] as $mark (
            $text;
            if $mark.type == "strong" then "**" + . + "**"
            elif $mark.type == "em" then "*" + . + "*"
            elif $mark.type == "code" then "`" + . + "`"
            elif $mark.type == "strike" then "~~" + . + "~~"
            elif $mark.type == "underline" then "*" + . + "*"
            elif $mark.type == "link" then "[" + . + "](" + ($mark.attrs.href // "") + ")"
            else . end
          )
        else $text end
      elif .type == "hardBreak" then "\n"
      elif .type == "heading" then
        (if .attrs.level == 1 then "# "
         elif .attrs.level == 2 then "## "
         else "## " end) +
        ([.content[]? | process] | join(""))
      elif .type == "bulletList" then
        [.content[]? |
          if .type == "listItem" then
            "- " + ([.content[]? | process] | join("\n  "))
          else process end
        ] | join("\n")
      elif .type == "orderedList" then
        [.content[]? |
          if .type == "listItem" then
            [.content[]? | process] | join("\n  ")
          else process end
        ] | to_entries | map((.key + 1 | tostring) + ". " + .value) | join("\n")
      elif .type == "listItem" then
        [.content[]? | process] | join("\n")
      elif .type == "codeBlock" then
        "```" + (.attrs.language // "") + "\n" +
        ([.content[]? | if .type == "text" then .text else "" end] | join("")) +
        "\n```"
      elif .type == "blockquote" then
        ([.content[]? | process] | join("\n") | split("\n") | map("> " + .) | join("\n"))
      elif .type == "rule" then "---"
      elif .type == "table" then
        [.content[]? |
          if .type == "tableRow" then
            "| " + ([.content[]? |
              if .type == "tableHeader" or .type == "tableCell" then
                [.content[]? | process] | join(" ")
              else " " end
            ] | join(" | ")) + " |"
          else process end
        ] | join("\n")
      elif .type == "tableRow" then
        "| " + ([.content[]? |
          if .type == "tableHeader" or .type == "tableCell" then
            [.content[]? | process] | join(" ")
          else " " end
        ] | join(" | ")) + " |"
      elif .type == "tableHeader" or .type == "tableCell" then
        [.content[]? | process] | join(" ")
      elif .type == "panel" then
        "> **" + (.attrs.panelType // "info") + "**\n> " +
        ([.content[]? | process] | join("\n") | split("\n") | join("\n> "))
      elif .type == "mediaSingle" or .type == "media" then
        if .attrs.url then "![" + (.attrs.alt // "image") + "](" + .attrs.url + ")"
        elif .content then [.content[]? | process] | join("")
        else "[Media]" end
      elif .type == "mention" then
        "@" + (.attrs.text // .attrs.id // "unknown")
      elif .type == "emoji" then
        .attrs.shortName // .attrs.text // ":emoji:"
      elif .type == "inlineCard" then
        .attrs.url // "[Card]"
      elif .content then
        [.content[]? | process] | join("")
      else
        ""
      end;

    process
  '
}

# Extract plain text from ADF (no markdown formatting)
# Usage: _adf_to_text '{"type":"doc","content":[...]}'
# Returns: Plain text string
_adf_to_text() {
  local adf_json="$1"

  if [ -z "$adf_json" ] || [ "$adf_json" = "null" ]; then
    echo ""
    return 0
  fi

  # Recursively extract all text content, ignoring formatting
  echo "$adf_json" | jq -r '
    def extract_text:
      if .type == "text" then
        .text
      elif .content then
        [.content[]? | extract_text] | join("")
      else
        ""
      end;

    extract_text
  '
}
