#!/usr/bin/env bash
# Bash completion for jira-helper
# Source this file or add it to your bash completion directory

# Tab completion for jira-helper/jira_helper dispatcher command
_jira_helper_completions() {
  # Remove colon from word breaks so hints like "PANK-1308:Github-tok" aren't split
  local COMP_WORDBREAKS="${COMP_WORDBREAKS//:}"

  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local cmd="${COMP_WORDS[1]}"

  # DEBUG: Uncomment to troubleshoot completion
  # echo "CWORD=$COMP_CWORD WORDS=(${COMP_WORDS[@]}) cur='$cur' prev='$prev' cmd='$cmd'" >> /tmp/jh-debug.log

  # If completing the command (first argument)
  if [ ${COMP_CWORD} -eq 1 ]; then
    local commands=(
      "help"
      "info"
      "update"
      "workspace"
      "eod"
      "issue"
      "issues"
      "doc"
      "docs"
      "metrics"
    )
    COMPREPLY=($(compgen -W "${commands[*]}" -- "$cur"))
    return 0
  fi

  # Contextual completion for command parameters
  case "$cmd" in
    # NEW: Hierarchical issue command
    issue)
      # Second argument: subcommand or ticket key
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve transitions-first order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Build suggestions: subcommands first, then recently accessed ticket keys with titles
        local suggestions=()
        suggestions+=("open" "transitions" "comment" "update" "update-comment" "last-comment-id" "create" "create-subtask")

        # Add recently accessed tickets from cache with titles as hints (if cache dir exists)
        if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
          # Get up to 10 most recently modified jira-*.json files
          while IFS= read -r cache_file; do
            local ticket=$(basename "$cache_file" .json | sed 's/jira-//')
            # Only include valid ticket keys (PROJECT-123 format)
            if [[ "$ticket" =~ ^[A-Z]+-[0-9]+$ ]]; then
              # Extract summary and truncate to 10 chars, sanitize
              local summary=$(jq -r '.fields.summary // empty' "$cache_file" 2>/dev/null | head -c 10 | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g')
              if [ -n "$summary" ]; then
                suggestions+=("${ticket}:${summary}")
              else
                suggestions+=("$ticket")
              fi
            fi
          done < <(ls -t "$CACHE_DIR"/jira-*.json 2>/dev/null | grep -E 'jira-[A-Z]+-[0-9]+\.json$' | head -10)
        fi

        # Filter suggestions based on current input, preserving order
        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          # Match against ticket key (before colon) but show full hint
          local ticket="${suggestion%%:*}"
          if [[ "$ticket" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      elif [ ${COMP_CWORD} -eq 3 ]; then
        # Third argument: --json flag or ticket key (for transitions/comment/update/update-comment/create-subtask)
        if [ "$prev" = "open" ] || [ "$prev" = "transitions" ] || [ "$prev" = "comment" ] || [ "$prev" = "update" ] || [ "$prev" = "update-comment" ] || [ "$prev" = "last-comment-id" ] || [ "$prev" = "create-subtask" ]; then
          # Disable sorting to preserve recency order (bash 4.4+)
          compopt -o nosort 2>/dev/null || true

          # Suggest cached ticket keys with titles for transitions/comment subcommands
          if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
            local suggestions=()
            # Add recently accessed tickets from cache with titles as hints
            while IFS= read -r cache_file; do
              local ticket=$(basename "$cache_file" .json | sed 's/jira-//')
              # Only include valid ticket keys (PROJECT-123 format)
              if [[ "$ticket" =~ ^[A-Z]+-[0-9]+$ ]]; then
                # Extract summary and truncate to 10 chars, sanitize
                local summary=$(jq -r '.fields.summary // empty' "$cache_file" 2>/dev/null | head -c 10 | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g')
                if [ -n "$summary" ]; then
                  suggestions+=("${ticket}:${summary}")
                else
                  suggestions+=("$ticket")
                fi
              fi
            done < <(ls -t "$CACHE_DIR"/jira-*.json 2>/dev/null | grep -E 'jira-[A-Z]+-[0-9]+\.json' | head -10)

            # Filter suggestions based on current input, preserving order
            COMPREPLY=()
            for suggestion in "${suggestions[@]}"; do
              # Match against ticket key (before colon) but show full hint
              local ticket="${suggestion%%:*}"
              if [[ "$ticket" == "$cur"* ]]; then
                COMPREPLY+=("$suggestion")
              fi
            done
            return 0
          fi
          return 0
        else
          COMPREPLY=($(compgen -W "--json" -- "$cur"))
          return 0
        fi
      else
        # For positions >= 4: field type for update subcommand
        # Handle cases where ticket key contains colon (gets split by bash)
        # Example: "jh issue update PANK-1308:Github-tok st" becomes
        #          [jh, issue, update, PANK-1308, :, Github-tok, st]
        if [ "${COMP_WORDS[2]}" = "update" ]; then
          # Find the position after the ticket key (which may be split by colons)
          # Skip past "jh issue update" and the ticket key pattern
          local ticket_end=3
          # Move past ticket key and any colon-separated parts
          while [ $ticket_end -lt $COMP_CWORD ]; do
            local word="${COMP_WORDS[$ticket_end]}"
            # If we hit a colon or ticket continuation, keep going
            if [[ "$word" =~ ^[A-Z]+-[0-9]+$ ]] || [[ "$word" == ":" ]] || [[ "$word" =~ ^[A-Za-z0-9-]+$ && "${COMP_WORDS[$((ticket_end-1))]}" == ":" ]]; then
              ((ticket_end++))
            else
              break
            fi
          done

          # If current position is right after ticket key, suggest field types
          if [ $COMP_CWORD -eq $ticket_end ]; then
            # Disable sorting to preserve logical order (bash 4.4+)
            compopt -o nosort 2>/dev/null || true

            local field_types=("priority" "assignee" "status")
            COMPREPLY=()
            for field_type in "${field_types[@]}"; do
              if [[ "$field_type" == "$cur"* ]]; then
                COMPREPLY+=("$field_type")
              fi
            done
            return 0
          # If current position is one after field type, suggest field values
          elif [ $COMP_CWORD -eq $((ticket_end + 1)) ]; then
            local field_type="${COMP_WORDS[$ticket_end]}"

            case "$field_type" in
              priority)
                # Suggest priority values
                compopt -o nosort 2>/dev/null || true
                local priorities=("Highest:1" "High:2" "Medium:3" "Low:4" "Lowest:5")
                COMPREPLY=()
                for priority in "${priorities[@]}"; do
                  local name="${priority%%:*}"
                  local id="${priority##*:}"
                  # Match against both name and ID
                  if [[ "$name" == "$cur"* ]] || [[ "$id" == "$cur"* ]]; then
                    COMPREPLY+=("$name" "$id")
                  fi
                done
                # Remove duplicates
                COMPREPLY=($(printf "%s\n" "${COMPREPLY[@]}" | sort -u))
                return 0
                ;;
              status)
                # Suggest status transitions - fetch them live if not cached
                # Reconstruct ticket key from split parts
                local ticket_key=""
                local pos=3
                while [ $pos -lt $ticket_end ]; do
                  ticket_key="${ticket_key}${COMP_WORDS[$pos]}"
                  ((pos++))
                done

                compopt -o nosort 2>/dev/null || true

                # Try to get transitions - fetch live if needed
                local transitions=""
                if type -t get_jira_transitions &>/dev/null; then
                  # Fetch transitions (will use cache if available)
                  # Use sed to capture ID and full transition name (including multi-word names)
                  # Note: Lines start with digits (no leading whitespace)
                  transitions=$(get_jira_transitions "$ticket_key" 2>&1 | grep "^[0-9]" | sed -E 's/^([0-9]+)\s+(.*)$/\1:\2/')
                fi

                if [ -n "$transitions" ]; then
                  COMPREPLY=()
                  while IFS=: read -r id name; do
                    if [[ "$id" == "$cur"* ]] || [[ "$name" == "$cur"* ]]; then
                      COMPREPLY+=("$id:$name")
                    fi
                  done <<< "$transitions"
                  return 0
                else
                  # No transitions available
                  COMPREPLY=("(no transitions available)")
                  return 0
                fi
                ;;
            esac
          fi
        fi
      fi
      ;;

    # NEW: Hierarchical issues command
    issues)
      # Second argument: subcommand
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve logical order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Build suggestions in logical order: mine (default), then search
        local suggestions=("mine" "search")

        # Filter suggestions based on current input, preserving order
        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          if [[ "$suggestion" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      fi
      ;;

    # NEW: Hierarchical doc command
    doc)
      # Second argument: subcommand or page ID
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve subcommands-first order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Build suggestions array: subcommands first, then page IDs with titles
        local suggestions=()

        # Add subcommands first (alphabetically sorted)
        suggestions+=("open" "set-source" "source" "update" "replace")

        # Add recently accessed pages from cache with titles as hints
        if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
          # Get up to 10 most recently modified confluence-*.json files
          while IFS= read -r cache_file; do
            local page_id=$(basename "$cache_file" .json | sed 's/confluence-//')
            # Only include valid page IDs (numeric format)
            if [[ "$page_id" =~ ^[0-9]+$ ]]; then
              # Extract title and sanitize (replace spaces with hyphens, keep only alphanumeric and hyphens)
              local title=$(jq -r '.title // empty' "$cache_file" 2>/dev/null | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g')
              if [ -n "$title" ]; then
                suggestions+=("${page_id}:${title}")
              else
                suggestions+=("$page_id")
              fi
            fi
          done < <(ls -t "$CACHE_DIR"/confluence-*.json 2>/dev/null | head -10)
        fi

        # Filter suggestions based on current input, preserving order
        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          # Match against page ID (before colon) but show full hint
          local page_id="${suggestion%%:*}"
          if [[ "$page_id" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      elif [ ${COMP_CWORD} -eq 3 ]; then
        # Third argument: page ID for source/set-source/update/replace subcommands
        if [ "$prev" = "open" ] || [ "$prev" = "source" ] || [ "$prev" = "set-source" ] || [ "$prev" = "update" ] || [ "$prev" = "replace" ]; then
          if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
            # Disable sorting to preserve recency order (bash 4.4+)
            compopt -o nosort 2>/dev/null || true

            local suggestions=()
            while IFS= read -r cache_file; do
              local page_id=$(basename "$cache_file" .json | sed 's/confluence-//')
              if [[ "$page_id" =~ ^[0-9]+$ ]]; then
                local title=$(jq -r '.title // empty' "$cache_file" 2>/dev/null | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-]//g')
                if [ -n "$title" ]; then
                  suggestions+=("${page_id}:${title}")
                else
                  suggestions+=("$page_id")
                fi
              fi
            done < <(ls -t "$CACHE_DIR"/confluence-*.json 2>/dev/null | head -10)
            # Filter suggestions based on current input, preserving order
            COMPREPLY=()
            for suggestion in "${suggestions[@]}"; do
              # Match against page ID (before colon) but show full hint
              local page_id="${suggestion%%:*}"
              if [[ "$page_id" == "$cur"* ]]; then
                COMPREPLY+=("$suggestion")
              fi
            done
            return 0
          fi
        fi
        return 0
      fi
      ;;

    # NEW: Hierarchical docs command
    docs)
      # Second argument: subcommand
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve logical order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Build suggestions in logical order: mine (default), then sources
        local suggestions=("mine" "sources")

        # Filter suggestions based on current input, preserving order
        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          if [[ "$suggestion" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      fi
      ;;

    eod)
      # Second argument: days (numeric) or template
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve hint order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Suggest days first (with hints), then templates
        local suggestions=("1:default" "7:week" "30:month" "slack" "slack_compact" "slack_plain" "default")

        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          # Match against main value (before colon)
          local value="${suggestion%%:*}"
          if [[ "$value" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      elif [ ${COMP_CWORD} -eq 3 ]; then
        # Third argument: template (if second was days) or days (if second was template)
        # Check if previous arg was numeric (days) or a template name
        if [[ "${COMP_WORDS[2]}" =~ ^[0-9]+$ ]] || [[ "${COMP_WORDS[2]}" =~ ^[0-9]+: ]]; then
          # Previous was days, suggest templates
          COMPREPLY=($(compgen -W "slack slack_compact slack_plain default" -- "$cur"))
        else
          # Previous was template, suggest days with hints
          compopt -o nosort 2>/dev/null || true
          local suggestions=("1:default" "7:week" "30:month")
          COMPREPLY=()
          for suggestion in "${suggestions[@]}"; do
            local value="${suggestion%%:*}"
            if [[ "$value" == "$cur"* ]]; then
              COMPREPLY+=("$suggestion")
            fi
          done
        fi
        return 0
      fi
      ;;

    # NEW: Hierarchical metrics command
    metrics)
      # Second argument: subcommand
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve logical order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Build suggestions in logical order
        local suggestions=("volume" "creation" "age" "priority" "churn" "personal" "painpoints")

        # Filter suggestions based on current input, preserving order
        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          if [[ "$suggestion" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      fi
      ;;

    # NEW: Hierarchical workspace command
    workspace)
      # Second argument: subcommand
      if [ ${COMP_CWORD} -eq 2 ]; then
        # Disable sorting to preserve logical order (bash 4.4+)
        compopt -o nosort 2>/dev/null || true

        # Build suggestions in logical order
        local suggestions=("list" "discover" "stats" "cleanup")

        # Filter suggestions based on current input, preserving order
        COMPREPLY=()
        for suggestion in "${suggestions[@]}"; do
          if [[ "$suggestion" == "$cur"* ]]; then
            COMPREPLY+=("$suggestion")
          fi
        done
        return 0
      fi
      ;;

    get-issue|show-issue)
      # Second argument: ticket key or --json flag
      if [ ${COMP_CWORD} -eq 2 ]; then
        local suggestions="--json"

        # Add recently accessed tickets from cache (only valid ticket keys)
        if [ -n "$CACHE_DIR" ] && [ -d "$CACHE_DIR" ]; then
          local recent_tickets=$(ls -t "$CACHE_DIR"/jira-*.json 2>/dev/null | sed 's/.*jira-\(.*\)\.json/\1/' | grep -E '^[A-Z]+-[0-9]+$' | head -10)
          if [ -n "$recent_tickets" ]; then
            suggestions="$suggestions $recent_tickets"
          fi
        fi

        COMPREPLY=($(compgen -W "$suggestions" -- "$cur"))
        return 0
      elif [ ${COMP_CWORD} -eq 3 ]; then
        # Third argument: --json flag
        COMPREPLY=($(compgen -W "--json" -- "$cur"))
        return 0
      fi
      ;;
  esac
}

# Tab completion for individual jira-helper functions
_jira_helper_function_completions() {
  # Remove colon from word breaks so hints like "PANK-1308:Github-tok" aren't split
  local COMP_WORDBREAKS="${COMP_WORDBREAKS//:}"

  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"
  local func="${COMP_WORDS[0]}"

  # Contextual completion based on function name
  case "$func" in
    eod_report)
      if [ ${COMP_CWORD} -eq 1 ]; then
        # First arg: days (numeric, skip suggestions)
        return 0
      elif [ ${COMP_CWORD} -eq 2 ]; then
        # Second arg: template
        COMPREPLY=($(compgen -W "slack slack_compact slack_plain default" -- "$cur"))
        return 0
      fi
      ;;
    add_jira_comment)
      if [ ${COMP_CWORD} -eq 3 ]; then
        # Third arg: --direct flag
        COMPREPLY=($(compgen -W "--direct" -- "$cur"))
        return 0
      fi
      ;;
    create_jira_ticket)
      if [ ${COMP_CWORD} -eq 4 ]; then
        # Fourth arg: issue type
        COMPREPLY=($(compgen -W "Task Story Bug Epic" -- "$cur"))
        return 0
      fi
      ;;
  esac

  # If completing first word, show all functions
  if [ ${COMP_CWORD} -eq 0 ]; then
    local functions=(
      "jira_helper_cmd"
      "jira_helper_info"
      "self_update"
      "eod_report"
      "jira_metrics_volume"
      "jira_metrics_creation"
      "jira_metrics_age"
      "jira_metrics_priority"
      "jira_metrics_churn"
      "jira_metrics_personal"
      "jira_metrics_painpoints"
      "get_jira_issue"
      "search_my_jira_updates"
      "create_jira_ticket"
      "add_jira_comment"
      "add_jira_labels"
      "update_jira_issue"
      "get_confluence_page"
      "search_my_confluence_updates"
    )
    COMPREPLY=($(compgen -W "${functions[*]}" -- "$cur"))
    return 0
  fi
}

# Register completion for main dispatcher
complete -F _jira_helper_completions jira_helper
complete -F _jira_helper_completions jira-helper
complete -F _jira_helper_completions jh  # Ultra-short alias

# Register completions for hyphenated aliases (primary interface)
complete -F _jira_helper_function_completions jira-helper-cmd
complete -F _jira_helper_function_completions jira-helper-info
complete -F _jira_helper_function_completions jira-info
complete -F _jira_helper_function_completions self-update
complete -F _jira_helper_function_completions eod-report

# Note: Underscore function names still work but won't appear in tab completion
# to keep the interface clean. Users should prefer hyphenated aliases.
# Metrics commands have been moved under 'jira-helper metrics' hierarchy.
