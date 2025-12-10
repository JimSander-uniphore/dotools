# eod-formatter.sh - Post-process EOD report for better scannability
#
# Provides functions to reformat verbose EOD output into scannable summaries

# Format EOD Jira issues for better scannability
# Takes raw jira_issues output and restructures it with key work done
# Usage: format_eod_jira_issues "$jira_issues"
format_eod_jira_issues() {
  local raw_issues="$1"

  # If no issues or error, return as-is
  if [ -z "$raw_issues" ] || [[ "$raw_issues" == *"No Jira issues"* ]]; then
    echo "$raw_issues"
    return 0
  fi

  # Process each issue to extract key information
  # Format: [KEY] [Priority] Status : Title
  #   Key work done (bullet points)
  #   Status info (if blocked/done)

  echo "$raw_issues" | awk '
    BEGIN {
      current_issue = ""
      issue_line = ""
      comment = ""
      in_comment = 0
    }

    # Match issue header lines like:  [PANK-1234](url) [High] Status : Title
    /^\s*\[.*\]\(.*\) \[.*\] .* : / {
      # Output previous issue if exists
      if (current_issue != "") {
        print_issue()
      }

      # Extract components
      issue_line = $0
      # Remove leading whitespace
      gsub(/^[ \t]+/, "", issue_line)

      # Extract key, priority, status, title
      match(issue_line, /\[([A-Z]+-[0-9]+)\]/, key_arr)
      match(issue_line, /\[([^\]]+)\] ([^ ]+) : (.+)$/, info_arr)

      current_issue = key_arr[1]
      priority = info_arr[1]
      status = info_arr[2]
      title = info_arr[3]

      comment = ""
      in_comment = 0
      next
    }

    # Match comment start (lines with leading spaces and a dash)
    /^\s+-/ {
      in_comment = 1
      # Remove leading whitespace and dash
      line = $0
      gsub(/^[ \t]+-[ \t]*/, "", line)

      # Try to extract key work done
      # Look for patterns like "Status:", "Key Achievements:", bullet points
      if (line ~ /^(Status|Key Achievements|Next Steps|Implementation|Architecture|Documentation|Testing|Simplification):/) {
        if (comment != "") comment = comment "\n  "
        comment = comment line
      } else if (length(comment) < 200) {
        # Only keep first ~200 chars of detail
        if (comment != "") comment = comment " "
        comment = comment line
      }
      next
    }

    # Continuation of comment (indented lines)
    in_comment == 1 && /^\s+/ {
      line = $0
      gsub(/^[ \t]+/, "", line)
      if (length(comment) < 200 && line != "") {
        comment = comment " " line
      }
      next
    }

    # Blank line or non-indented text ends comment
    /^$/ || /^[^ \t]/ {
      in_comment = 0
    }

    END {
      # Output last issue
      if (current_issue != "") {
        print_issue()
      }
    }

    function print_issue() {
      # Format output
      printf "%s [%s] %s : %s\n", current_issue, priority, status, title

      # Add condensed comment if exists
      if (comment != "") {
        # Split on key sections and output as bullets
        if (comment ~ /Status:/) {
          split(comment, parts, /Status:/)
          if (length(parts) > 1) {
            gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
            printf "  Status: %s\n", substr(parts[2], 1, 100)
          }
        }
        if (comment ~ /Implementation:/) {
          split(comment, parts, /Implementation:/)
          if (length(parts) > 1) {
            gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
            printf "  Work: %s\n", substr(parts[2], 1, 150)
          }
        }
        if (comment ~ /Architecture:/) {
          split(comment, parts, /Architecture:/)
          if (length(parts) > 1) {
            gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
            printf "  Work: %s\n", substr(parts[2], 1, 150)
          }
        }

        # If no structured sections found, just show first line
        if (comment !~ /(Status|Implementation|Architecture):/) {
          gsub(/^[ \t]+|[ \t]+$/, "", comment)
          printf "  %s\n", substr(comment, 1, 150)
        }
      }

      printf "\n"
    }
  '
}
