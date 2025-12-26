#!/usr/bin/env zsh
# info.sh - Information and status commands

cmd_ls() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || die "Usage: wt ls [--json] <repo>"

  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || true
  [[ -n "$out" ]] || { dim "No worktrees found."; return 0; }

  local json_items=()

  display_worktree() {
    local idx="$1" path="$2" branch="$3" head="$4"
    local folder="${path:t}"
    local url
    if [[ -f "$path/.env" ]]; then
      url="$(grep -E '^APP_URL=' "$path/.env" 2>/dev/null | head -1 | cut -d'=' -f2- | sed 's/#.*//' | tr -d '"' | tr -d "'" | tr -d ' ')"
    fi
    [[ -z "$url" ]] && url="https://${folder}.test"
    local sha; sha="$(git -C "$path" rev-parse --short HEAD 2>/dev/null || true)"
    local st; st="$(git -C "$path" status --porcelain 2>/dev/null || true)"
    local state_icon="●" state_color="$C_GREEN" state_text="clean"
    local dirty=false
    local mismatch=false

    if [[ -n "$st" ]]; then
      local changes; changes="$(print -r -- "$st" | wc -l | tr -d ' ')"
      state_icon="◐"
      state_color="$C_YELLOW"
      state_text="$changes uncommitted"
      dirty=true
    fi

    # Check for branch/directory mismatch
    local match_result="" expected_slug=""
    if [[ -n "$branch" ]]; then
      match_result="$(check_branch_directory_match "$path" "$branch" "$repo")"
      if [[ "$match_result" == mismatch\|* ]]; then
        mismatch=true
        expected_slug="${match_result#mismatch|}"
      fi
    fi

    # Get ahead/behind
    local counts; counts="$(get_ahead_behind "$path" "$DEFAULT_BASE")"
    local ahead="${counts%% *}" behind="${counts##* }"

    if [[ "$JSON_OUTPUT" == true ]]; then
      json_items+=("{\"path\": \"$(json_escape "$path")\", \"branch\": \"$(json_escape "$branch")\", \"sha\": \"$(json_escape "$sha")\", \"url\": \"$(json_escape "$url")\", \"dirty\": $dirty, \"ahead\": $ahead, \"behind\": $behind, \"mismatch\": $mismatch}")
    else
      print -r -- "${C_BOLD}[$idx]${C_RESET} ${C_CYAN}$path${C_RESET}"
      if [[ -n "$branch" ]]; then
        print -r -- "    ${C_DIM}branch${C_RESET}  ${C_MAGENTA}$branch${C_RESET}"
      else
        [[ -n "$head" ]] && print -r -- "    ${C_DIM}head${C_RESET}    ${C_YELLOW}${head:0:12}${C_RESET} (detached)"
      fi
      [[ -n "$sha" ]] && print -r -- "    ${C_DIM}sha${C_RESET}     ${C_DIM}$sha${C_RESET}"
      print -r -- "    ${C_DIM}state${C_RESET}   ${state_color}${state_icon} ${state_text}${C_RESET}"
      if (( ahead > 0 || behind > 0 )); then
        print -r -- "    ${C_DIM}sync${C_RESET}    ${C_GREEN}↑$ahead${C_RESET} ${C_RED}↓$behind${C_RESET}"
      fi
      print -r -- "    ${C_DIM}url${C_RESET}     ${C_BLUE}$url${C_RESET}"
      print -r -- "    ${C_DIM}cd${C_RESET}      ${C_DIM}cd ${(q)path}${C_RESET}"
      if [[ "$mismatch" == true ]]; then
        print -r -- "    ${C_RED}MISMATCH${C_RESET} Directory name doesn't match branch!"
        print -r -- "      ${C_DIM}Expected:${C_RESET} ${repo}--${expected_slug}"
      fi
      print -r -- ""
    fi
  }

  local path="" branch="" head="" idx=0 line=""
  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ -n "$path" ]]; then
        idx=$((idx + 1))
        display_worktree "$idx" "$path" "$branch" "$head"
      fi
      path=""; branch=""; head=""
      continue
    fi

    [[ "$line" == worktree\ * ]] && path="${line#worktree }"
    [[ "$line" == branch\ refs/heads/* ]] && branch="${line#branch refs/heads/}"
    [[ "$line" == HEAD\ * ]] && head="${line#HEAD }"
  done <<< "$out"

  # Handle last entry (no trailing blank line)
  if [[ -n "$path" ]]; then
    idx=$((idx + 1))
    display_worktree "$idx" "$path" "$branch" "$head"
  fi

  if [[ "$JSON_OUTPUT" == true ]]; then
    format_json "[${(j:, :)json_items}]"
  fi
}

cmd_status() {
  local repo="${1:-}"
  local stale_threshold=50
  local inactive_days=30

  [[ -n "$repo" ]] || die "Usage: wt status <repo>"

  validate_name "$repo" "repository"

  local git_dir
  git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  info "Fetching latest..."
  git --git-dir="$git_dir" fetch --all --prune --quiet

  local out
  out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || true
  [[ -n "$out" ]] || { dim "No worktrees found."; return 0; }

  # JSON output mode
  local json_items=()

  if [[ "$JSON_OUTPUT" != true ]]; then
    print -r -- ""
    print -r -- "${C_BOLD}Worktree Status: ${C_CYAN}$repo${C_RESET}"
    print -r -- ""
    printf "  ${C_DIM}%-28s %-10s %-14s %-6s %-7s %-10s${C_RESET}\n" "BRANCH" "STATE" "SYNC" "AGE" "MERGED" "SHA"
    print -r -- "  ${C_DIM}$(printf '%.0s─' {1..83})${C_RESET}"
  fi

  local path="" branch="" head="" line=""
  local sha st state_icon state_color changes counts ahead behind
  local age age_days merged_icon sync_display is_stale is_inactive
  local mismatches=()

  # Helper to display a worktree row
  display_status_row() {
    local p="$1" b="$2"

    sha="$(git -C "$p" rev-parse --short HEAD 2>/dev/null)" || sha="?"
    st="$(git -C "$p" status --porcelain 2>/dev/null)" || st=""
    state_icon="●"
    state_color="$C_GREEN"
    is_stale=false
    is_inactive=false

    if [[ -n "$st" ]]; then
      changes="$(print -r -- "$st" | wc -l | tr -d ' ')"
      state_icon="◐ $changes"
      state_color="$C_YELLOW"
    fi

    # Check for mismatch
    local match_result="$(check_branch_directory_match "$p" "$b" "$repo")"
    if [[ "$match_result" == mismatch\|* ]]; then
      local expected_slug="${match_result#mismatch|}"
      mismatches+=("${p:t}|$b|$expected_slug")
    fi

    # Get sync status
    counts="$(get_ahead_behind "$p" "$DEFAULT_BASE")"
    ahead="${counts%% *}"
    behind="${counts##* }"

    # Check if stale (>50 commits behind)
    if (( behind > stale_threshold )); then
      is_stale=true
      sync_display="${C_RED}↑$ahead ↓$behind${C_RESET}"
    else
      sync_display="↑$ahead ↓$behind"
    fi

    # Get age
    age="$(get_last_commit_age "$p")"
    age_days="$(get_commit_age_days "$p")"
    if (( age_days > inactive_days )); then
      is_inactive=true
    fi

    # Check if merged
    if is_branch_merged "$p" "$DEFAULT_BASE"; then
      merged_icon="${C_DIM}✓${C_RESET}"
    else
      merged_icon="${C_DIM}-${C_RESET}"
    fi

    # Apply row colouring for stale/inactive
    local branch_display="${b:0:26}"
    local age_display="$age"
    if [[ "$is_stale" == true ]]; then
      branch_display="${C_RED}${b:0:26}${C_RESET}"
      state_color="$C_RED"
    elif [[ "$is_inactive" == true ]]; then
      age_display="${C_YELLOW}$age${C_RESET}"
    fi

    if [[ "$JSON_OUTPUT" == true ]]; then
      local dirty=false
      [[ -n "$st" ]] && dirty=true
      local merged=false
      is_branch_merged "$p" "$DEFAULT_BASE" && merged=true
      json_items+=("{\"branch\": \"$(json_escape "$b")\", \"path\": \"$(json_escape "$p")\", \"sha\": \"$(json_escape "$sha")\", \"dirty\": $dirty, \"changes\": ${changes:-0}, \"ahead\": $ahead, \"behind\": $behind, \"stale\": $is_stale, \"age\": \"$age\", \"age_days\": $age_days, \"merged\": $merged}")
    else
      printf "  %-28s ${state_color}%-10s${C_RESET} %-14s %-6s %-7s ${C_DIM}%-10s${C_RESET}\n" \
        "$branch_display" "$state_icon" "$sync_display" "$age_display" "$merged_icon" "$sha"
    fi
  }

  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      # Skip bare repo entry (no branch) and process worktrees
      if [[ -n "$path" && -n "$branch" && "$path" != "$git_dir" ]]; then
        display_status_row "$path" "$branch"
      fi
      path=""
      branch=""
      head=""
      continue
    fi

    [[ "$line" == worktree\ * ]] && path="${line#worktree }"
    [[ "$line" == branch\ refs/heads/* ]] && branch="${line#branch refs/heads/}"
    [[ "$line" == HEAD\ * ]] && head="${line#HEAD }"
  done <<< "$out"

  # Handle last entry
  if [[ -n "$path" && -n "$branch" && "$path" != "$git_dir" ]]; then
    display_status_row "$path" "$branch"
  fi

  # JSON output
  if [[ "$JSON_OUTPUT" == true ]]; then
    format_json "[${(j:, :)json_items}]"
    return 0
  fi

  # Show mismatch warnings
  if (( ${#mismatches[@]} > 0 )); then
    print -r -- ""
    print -r -- "${C_RED}${C_BOLD}Branch/Directory Mismatches Detected:${C_RESET}"
    for m in "${mismatches[@]}"; do
      local dir="${m%%|*}"
      local rest="${m#*|}"
      local actual_branch="${rest%%|*}"
      local expected_slug="${rest#*|}"
      print -r -- "  ${C_YELLOW}$dir${C_RESET}"
      print -r -- "    ${C_DIM}Current branch:${C_RESET}  ${C_MAGENTA}$actual_branch${C_RESET}"
      print -r -- "    ${C_DIM}Expected dir:${C_RESET}    ${repo}--${expected_slug}"
      print -r -- "    ${C_DIM}Fix:${C_RESET} Checkout correct branch or recreate worktree"
    done
  fi

  print -r -- ""
}

cmd_repos() {
  local repos; repos="$(list_repos)"

  if [[ -z "$repos" ]]; then
    dim "No repositories found in $HERD_ROOT"
    return 0
  fi

  if [[ "$JSON_OUTPUT" == true ]]; then
    local json_items=()
    while IFS= read -r repo; do
      local git_dir; git_dir="$(git_dir_for "$repo")"
      local wt_count; wt_count="$(git --git-dir="$git_dir" worktree list 2>/dev/null | wc -l | tr -d ' ')"
      wt_count=$((wt_count - 1))  # Subtract bare repo entry
      json_items+=("{\"name\": \"$(json_escape "$repo")\", \"worktrees\": $wt_count}")
    done <<< "$repos"
    format_json "[${(j:, :)json_items}]"
  else
    print -r -- ""
    print -r -- "${C_BOLD}Repositories in ${C_CYAN}$HERD_ROOT${C_RESET}"
    print -r -- ""
    while IFS= read -r repo; do
      local git_dir; git_dir="$(git_dir_for "$repo")"
      local wt_count; wt_count="$(git --git-dir="$git_dir" worktree list 2>/dev/null | wc -l | tr -d ' ')"
      wt_count=$((wt_count - 1))  # Subtract bare repo entry
      print -r -- "  ${C_GREEN}$repo${C_RESET} ${C_DIM}($wt_count worktrees)${C_RESET}"
    done <<< "$repos"
    print -r -- ""
  fi
}

cmd_report() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || die "Usage: wt report <repo> [--output <file>]"
  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  local output_file=""
  if [[ "${2:-}" == "--output" && -n "${3:-}" ]]; then
    output_file="$3"
  fi

  # Generate markdown report
  local report=""
  report+="# Worktree Report: $repo\n\n"
  report+="Generated: $(date '+%Y-%m-%d %H:%M:%S')\n\n"

  # Get worktree list
  local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || true
  [[ -n "$out" ]] || { dim "No worktrees found."; return 0; }

  report+="## Summary\n\n"

  local total=0 clean=0 dirty=0
  local path="" branch="" head=""

  # First pass - count stats
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == worktree\ * ]]; then
      path="${line#worktree }"
    elif [[ "$line" == "branch refs/heads/"* ]]; then
      branch="${line#branch refs/heads/}"
    elif [[ "$line" == HEAD\ * ]]; then
      head="${line#HEAD }"
    elif [[ -z "$line" && -n "$path" ]]; then
      [[ "$path" == *.git ]] && { path=""; branch=""; head=""; continue; }
      total=$((total + 1))
      local status; status="$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
      if (( status > 0 )); then
        dirty=$((dirty + 1))
      else
        clean=$((clean + 1))
      fi
      path=""; branch=""; head=""
    fi
  done <<< "$out"

  report+="| Metric | Count |\n"
  report+="|--------|-------|\n"
  report+="| Total worktrees | $total |\n"
  report+="| Clean | $clean |\n"
  report+="| With changes | $dirty |\n\n"

  report+="## Worktrees\n\n"
  report+="| Branch | Status | Ahead | Behind | Last Commit |\n"
  report+="|--------|--------|-------|--------|-------------|\n"

  # Second pass - generate table
  path=""; branch=""; head=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == worktree\ * ]]; then
      path="${line#worktree }"
    elif [[ "$line" == "branch refs/heads/"* ]]; then
      branch="${line#branch refs/heads/}"
    elif [[ "$line" == HEAD\ * ]]; then
      head="${line#HEAD }"
    elif [[ -z "$line" && -n "$path" ]]; then
      [[ "$path" == *.git ]] && { path=""; branch=""; head=""; continue; }

      local status_count; status_count="$(git -C "$path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
      local status_icon="clean"
      (( status_count > 0 )) && status_icon="$status_count changes"

      local ahead=0 behind=0
      local upstream; upstream="$(git -C "$path" rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)" || upstream=""
      if [[ -n "$upstream" ]]; then
        ahead="$(git -C "$path" rev-list --count '@{upstream}'..HEAD 2>/dev/null)" || ahead=0
        behind="$(git -C "$path" rev-list --count HEAD..'@{upstream}' 2>/dev/null)" || behind=0
      fi

      local last_commit; last_commit="$(git -C "$path" log -1 --format='%s' 2>/dev/null | cut -c1-40)" || last_commit=""
      [[ ${#last_commit} -ge 40 ]] && last_commit="${last_commit}..."

      report+="| \`$branch\` | $status_icon | $ahead | $behind | $last_commit |\n"

      path=""; branch=""; head=""
    fi
  done <<< "$out"

  report+="\n## Hooks Available\n\n"
  if [[ -d "$WT_HOOKS_DIR" ]]; then
    for hook_type in pre-add post-add pre-rm post-rm post-pull post-sync; do
      if [[ -x "$WT_HOOKS_DIR/$hook_type" ]] || [[ -d "$WT_HOOKS_DIR/${hook_type}.d" ]]; then
        report+="- \`$hook_type\` (enabled)\n"
      else
        report+="- \`$hook_type\` (not configured)\n"
      fi
    done
  else
    report+="No hooks directory found at \`$WT_HOOKS_DIR\`\n"
  fi

  # Output report
  if [[ -n "$output_file" ]]; then
    print -r -- "$report" > "$output_file"
    ok "Report saved to: $output_file"
  else
    print -r -- "$report"
  fi
}

cmd_health() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || die "Usage: wt health <repo>"
  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  print -r -- ""
  print -r -- "${C_BOLD}Health Check: ${C_CYAN}$repo${C_RESET}"
  print -r -- ""

  local issues=0 warnings=0

  # Check for stale worktrees
  print -r -- "${C_BOLD}Stale Worktrees${C_RESET}"
  local stale; stale="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null | grep -A1 '^worktree ' | grep -v '^worktree ' | grep -v '^--$' | while read -r path; do
    [[ -n "$path" && ! -d "$path" ]] && echo "$path"
  done)"
  if [[ -n "$stale" ]]; then
    warn "Found stale worktree references:"
    print -r -- "$stale" | while read -r path; do
      print -r -- "  ${C_RED}x${C_RESET} $path"
    done
    issues=$((issues + 1))
    dim "  Fix: wt prune $repo"
  else
    ok "No stale worktrees"
  fi
  print -r -- ""

  # Check for orphaned databases
  print -r -- "${C_BOLD}Database Health${C_RESET}"
  if command -v mysql >/dev/null 2>&1; then
    local mysql_cmd=(mysql -h "$DB_HOST" -u "$DB_USER" -N -B)
    [[ -n "$DB_PASSWORD" ]] && mysql_cmd+=(-p"$DB_PASSWORD")

    local dbs; dbs="$("${mysql_cmd[@]}" -e "SHOW DATABASES LIKE '${repo}__%'" 2>/dev/null)" || dbs=""

    if [[ -n "$dbs" ]]; then
      local orphaned=0
      while read -r db; do
        local found=false
        local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || out=""
        while IFS= read -r line; do
          if [[ "$line" == worktree\ * ]]; then
            local wt_path="${line#worktree }"
            local wt_db; wt_db="$(db_name_for "$repo" "${wt_path##*--}")"
            [[ "$wt_db" == "$db" ]] && found=true && break
          fi
        done <<< "$out"

        if [[ "$found" == false ]]; then
          [[ $orphaned -eq 0 ]] && warn "Potentially orphaned databases:"
          print -r -- "  ${C_YELLOW}?${C_RESET} $db"
          orphaned=$((orphaned + 1))
        fi
      done <<< "$dbs"

      if [[ $orphaned -eq 0 ]]; then
        ok "No orphaned databases found"
      else
        warnings=$((warnings + orphaned))
        dim "  Verify and drop if not needed: mysql -e 'DROP DATABASE <name>'"
      fi
    else
      dim "  No databases found matching pattern ${repo}__*"
    fi
  else
    dim "  MySQL not available - skipping database checks"
  fi
  print -r -- ""

  # Check for missing .env files
  print -r -- "${C_BOLD}Environment Files${C_RESET}"
  local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || out=""
  local missing_env=0
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      local path="${line#worktree }"
      [[ "$path" == *.git ]] && continue
      if [[ -f "$path/.env.example" && ! -f "$path/.env" ]]; then
        [[ $missing_env -eq 0 ]] && warn "Worktrees missing .env file:"
        print -r -- "  ${C_YELLOW}!${C_RESET} ${path##*/}"
        missing_env=$((missing_env + 1))
      fi
    fi
  done <<< "$out"
  if [[ $missing_env -eq 0 ]]; then
    ok "All worktrees have .env files"
  else
    warnings=$((warnings + missing_env))
    dim "  Fix: cd <worktree> && cp .env.example .env"
  fi
  print -r -- ""

  # Check for branch/directory mismatches
  print -r -- "${C_BOLD}Branch Consistency${C_RESET}"
  local mismatches=0
  check_worktree_mismatches "$git_dir"
  mismatches=$?
  if [[ $mismatches -eq 0 ]]; then
    ok "All worktrees match their expected branches"
  else
    issues=$((issues + mismatches))
  fi
  print -r -- ""

  # Summary
  print -r -- "${C_BOLD}Summary${C_RESET}"
  if [[ $issues -eq 0 && $warnings -eq 0 ]]; then
    ok "No issues found - repository is healthy!"
  else
    [[ $issues -gt 0 ]] && warn "$issues issue(s) need attention"
    [[ $warnings -gt 0 ]] && dim "  $warnings warning(s) to review"
  fi
  print -r -- ""
}
