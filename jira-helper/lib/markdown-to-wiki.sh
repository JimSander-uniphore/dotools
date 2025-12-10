#!/usr/bin/env bash
# markdown-to-wiki.sh - Markdown to Confluence Wiki Markup conversion
#
# This module provides markdown-to-wiki conversion for Confluence pages.
# Handles: headings, tables, lists, inline formatting (bold, italic, code), links

# Convert markdown content to Confluence Wiki Markup
# Usage: _markdown_to_wiki "markdown content"
# Returns: Wiki markup string
_markdown_to_wiki() {
  local content="$1"
  local temp_file="${CACHE_DIR}/markdown-wiki-$$.tmp"

  # Stage 0: Extract and protect code blocks with placeholders
  local -a code_blocks
  local code_idx=0

  echo "$content" > "$temp_file"

  # Extract code blocks and replace with placeholders
  content=$("$AWK" '
    BEGIN { in_code = 0; code_lang = ""; code_content = ""; code_idx = 0; line_count = 0 }
    /^```/ {
      if (in_code == 0) {
        # Start of code block
        # Extract language (everything after ```)
        line = $0
        sub(/^```/, "", line)
        code_lang = line
        code_content = ""
        line_count = 0
        in_code = 1
      } else {
        # End of code block - save and emit placeholder
        # Check if single-line code block (no newlines in content)
        if (line_count == 1 && index(code_content, "\n") == 0) {
          # Single line - inline format
          if (code_lang != "") {
            print "{code:" code_lang "}" code_content "{code}" > "/tmp/code_block_" code_idx ".txt"
          } else {
            print "{code}" code_content "{code}" > "/tmp/code_block_" code_idx ".txt"
          }
        } else {
          # Multi-line - block format
          if (code_lang != "") {
            print "{code:" code_lang "}" > "/tmp/code_block_" code_idx ".txt"
          } else {
            print "{code}" > "/tmp/code_block_" code_idx ".txt"
          }
          print code_content >> "/tmp/code_block_" code_idx ".txt"
          print "{code}" >> "/tmp/code_block_" code_idx ".txt"
        }

        printf "___CODE_BLOCK_%d___\n", code_idx
        code_idx++
        in_code = 0
        code_lang = ""
        code_content = ""
        line_count = 0
      }
      next
    }
    in_code == 1 {
      # Inside code block - accumulate
      line_count++
      if (code_content != "") {
        code_content = code_content "\n" $0
      } else {
        code_content = $0
      }
      next
    }
    {
      # Outside code block - pass through
      print
    }
  ' "$temp_file")

  # Count code blocks for restoration
  local max_code_idx=$(echo "$content" | grep -c "___CODE_BLOCK_")

  # Stage 1: Tables (|...| format)
  content=$(echo "$content" | "$AWK" '
    BEGIN { in_table = 0; is_first_row = 1 }
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
      }

      # Parse row (header or data)
      line = $0
      gsub(/^\|[ \t]*/, "", line)
      gsub(/[ \t]*\|$/, "", line)

      if (is_first_row == 1) {
        # Header row: || cell || cell ||
        gsub(/[ \t]*\|[ \t]*/, " || ", line)
        print "|| " line " ||"
        is_first_row = 0
      } else {
        # Data row: | cell | cell |
        gsub(/[ \t]*\|[ \t]*/, " | ", line)
        print "| " line " |"
      }
      next
    }
    in_table == 1 {
      # End of table (non-table line encountered)
      in_table = 0
      is_first_row = 1
      print
      next
    }
    {
      print
    }
  ')

  # Stage 2: Headings (# through ######)
  content=$(echo "$content" | "$SED" -E '
    s/^###### (.+)$/h6. \1/
    s/^##### (.+)$/h5. \1/
    s/^#### (.+)$/h4. \1/
    s/^### (.+)$/h3. \1/
    s/^## (.+)$/h2. \1/
    s/^# (.+)$/h1. \1/
  ')

  # Stage 3: Lists (ordered and unordered)
  content=$(echo "$content" | "$AWK" '
    /^[0-9]+\. / {
      # Numbered list item - convert to wiki markup
      sub(/^[0-9]+\. /, "# ")
      print
      next
    }
    /^- / {
      # Unordered list with dash - convert to asterisk
      sub(/^- /, "* ")
      print
      next
    }
    /^\* / {
      # Already unordered list with asterisk - keep as is
      print
      next
    }
    {
      # Not a list item
      print
    }
  ')

  # Stage 4: Inline formatting (must come after tables to avoid breaking table markers)

  # Bold: **text** or __text__ → *text*
  content=$(echo "$content" | "$SED" -E '
    s/\*\*([^*]+)\*\*/*\1*/g
    s/__([^_]+)__/*\1*/g
  ')

  # Italic: *text* or _text_ → _text_ (but not ** or __)
  # Note: In wiki markup, * is bold, _ is italic
  content=$(echo "$content" | "$SED" -E '
    s/([^*])\*([^*]+)\*([^*])/\1_\2_\3/g
  ')

  # Inline code: `code` → {{code}}
  content=$(echo "$content" | "$SED" -E 's/`([^`]+)`/{{\1}}/g')

  # Stage 4a: Convert relative markdown links to GitHub URLs
  # Detect GitHub repo URL from git remote
  local github_base_url=""
  if git rev-parse --git-dir > /dev/null 2>&1; then
    local git_remote
    git_remote=$(git remote get-url origin 2>/dev/null || echo "")

    if [[ "$git_remote" =~ github.com ]]; then
      # Convert SSH or HTTPS URL to base GitHub URL
      # git@github.com:org/repo.git → https://github.com/org/repo
      # https://github.com/org/repo.git → https://github.com/org/repo
      github_base_url=$(echo "$git_remote" | "$SED" -E '
        s|^git@github\.com:|https://github.com/|
        s|^https://github\.com/||
        s|\.git$||
      ')
      github_base_url="https://github.com/${github_base_url}"

      # Use version tag for documentation links (more stable than branch)
      # Fall back to main branch if no tags exist
      local ref
      ref=$(git describe --tags --abbrev=0 2>/dev/null || echo "main")

      # Get repo root and current directory to calculate relative path
      local repo_root
      repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")

      # Use the directory of the source file being processed, not pwd
      # This is set by caller via MARKDOWN_SOURCE_DIR env var
      local current_dir
      if [ -n "$MARKDOWN_SOURCE_DIR" ]; then
        current_dir="$MARKDOWN_SOURCE_DIR"
      else
        current_dir=$(pwd)
      fi

      # Calculate subdirectory path from repo root
      local subdir_path=""
      if [ -n "$repo_root" ]; then
        subdir_path="${current_dir#${repo_root}/}"
        if [ "$subdir_path" != "$current_dir" ]; then
          subdir_path="${subdir_path}/"
        else
          subdir_path=""
        fi
      fi

      # Convert relative .md links to absolute GitHub URLs
      # Use perl with logic to resolve ../ paths properly
      content=$(echo "$content" | perl -pe "
        sub resolve_path {
          my (\$base, \$rel) = @_;
          my @parts = split('/', \$base);
          pop @parts if \$parts[-1] eq '';  # Remove trailing empty
          foreach my \$part (split('/', \$rel)) {
            if (\$part eq '..') {
              pop @parts;
            } elsif (\$part ne '.' && \$part ne '') {
              push @parts, \$part;
            }
          }
          return join('/', @parts);
        }
        s{\\[([^\\]]+)\\]\\((\\.\\.?/(?:[^)]+\\.md))\\)}{
          my \$text = \$1;
          my \$path = resolve_path('${subdir_path}', \$2);
          \"[\$text|${github_base_url}/blob/${ref}/\$path]\";
        }ge;
        s{\\[([^\\]]+)\\]\\(((?:[^/]+/)*[^)]+\\.md)\\)}{[\$1|${github_base_url}/blob/${ref}/${subdir_path}\$2]}g;
      ")
    fi
  fi

  # Links: [text](url) → [text|url] (for remaining non-md links)
  content=$(echo "$content" | "$SED" -E 's/\[([^\]]+)\]\(([^)]+)\)/[\1|\2]/g')

  # Stage 5: Restore code blocks from placeholders
  # Write content to temp file for processing
  echo "$content" > "${temp_file}.processed"

  for ((i=0; i<max_code_idx; i++)); do
    if [ -f "/tmp/code_block_${i}.txt" ]; then
      # Use perl for multiline-safe replacement
      perl -i -pe "
        BEGIN {
          open(my \$fh, '<', '/tmp/code_block_${i}.txt');
          \$replacement = do { local \$/; <\$fh> };
          close(\$fh);
        }
        s/___CODE_BLOCK_${i}___/\$replacement/g;
      " "${temp_file}.processed"
      rm "/tmp/code_block_${i}.txt"
    fi
  done

  # Output the converted content (metadata is stored via Content Properties API, not in content)
  cat "${temp_file}.processed"
  rm -f "$temp_file" "${temp_file}.processed"
}
