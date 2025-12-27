#!/usr/bin/env zsh
# git-ops.sh - Git operation commands

cmd_pull() {
  local repo="${1:-}"; local branch="${2:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
    dim "  Detected: $repo / $branch"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to pull")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt pull [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"

  ensure_bare_repo "$git_dir"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  info "Pulling latest changes in ${C_MAGENTA}$branch${C_RESET}..."
  GIT_SSH_COMMAND="/usr/bin/ssh" /usr/bin/git -C "$wt_path" pull --rebase
  ok "Pull complete"

  # Run post-pull hooks
  local app_url; app_url="$(url_for "$repo" "$branch")"
  local db_name; db_name="$(db_name_for "$repo" "$branch")"
  run_hooks "post-pull" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"
}

cmd_pull_all() {
  local repo="${1:-}"

  # Multi-repo mode
  if [[ "${ALL_REPOS:-false}" == true || -z "$repo" ]]; then
    if [[ "${ALL_REPOS:-false}" == true ]]; then
      info "Pulling all worktrees across all repositories..."
      print -r -- ""
    else
      [[ -n "$repo" ]] || die "Usage: wt pull-all <repo>
       Use --all-repos to pull across all repositories."
    fi

    local total_success=0 total_failed=0
    for git_dir in "$HERD_ROOT"/*.git(N); do
      [[ -d "$git_dir" ]] || continue
      local repo_name="${${git_dir:t}%.git}"
      print -r -- "${C_BOLD}${C_CYAN}$repo_name${C_RESET}"
      _pull_all_for_repo "$repo_name" "$git_dir"
      print -r -- ""
    done

    ok "Pull complete across all repositories"
    return 0
  fi

  validate_name "$repo" "repository"

  local git_dir
  git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  _pull_all_for_repo "$repo" "$git_dir"
}

_pull_all_for_repo() {
  local repo="$1"
  local git_dir="$2"

  dim "  Fetching latest..."
  git --git-dir="$git_dir" fetch --all --prune --quiet 2>/dev/null || true

  local out
  out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || true
  [[ -n "$out" ]] || { dim "No worktrees found."; return 0; }

  # Collect worktrees first
  local worktrees=()
  local path="" branch="" line=""

  while IFS= read -r line; do
    if [[ -z "$line" ]]; then
      if [[ -n "$path" && -n "$branch" && "$path" != "$git_dir" && -d "$path" ]]; then
        worktrees+=("$path|$branch")
      fi
      path=""
      branch=""
      continue
    fi
    [[ "$line" == worktree\ * ]] && path="${line#worktree }"
    [[ "$line" == branch\ refs/heads/* ]] && branch="${line#branch refs/heads/}"
  done <<< "$out"

  # Handle last entry
  if [[ -n "$path" && -n "$branch" && "$path" != "$git_dir" && -d "$path" ]]; then
    worktrees+=("$path|$branch")
  fi

  # Pull each worktree in parallel
  local total=${#worktrees[@]}
  local count=0 failed=0
  export GIT_SSH_COMMAND="/usr/bin/ssh"

  info "Pulling $total worktree(s) in parallel..."

  # Create temp directory for results
  local tmpdir; tmpdir="$(/usr/bin/mktemp -d)"
  trap "/bin/rm -rf '$tmpdir'" EXIT

  # Launch parallel pulls
  local pids=()
  local idx=0
  for wt_entry in "${worktrees[@]}"; do
    local wt_path="${wt_entry%%|*}"
    local wt_branch="${wt_entry##*|}"

    (
      if /usr/bin/git -C "$wt_path" pull --rebase >/dev/null 2>&1; then
        print -r -- "ok" > "$tmpdir/$idx"
      else
        print -r -- "fail" > "$tmpdir/$idx"
      fi
    ) &
    pids+=($!)
    idx=$((idx + 1))
  done

  # Wait for all to complete
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Collect results
  idx=0
  for wt_entry in "${worktrees[@]}"; do
    local wt_branch="${wt_entry##*|}"
    if [[ -f "$tmpdir/$idx" && "$(/bin/cat "$tmpdir/$idx")" == "ok" ]]; then
      ok "  $wt_branch"
      count=$((count + 1))
    else
      warn "  $wt_branch - failed"
      failed=$((failed + 1))
    fi
    idx=$((idx + 1))
  done

  /bin/rm -rf "$tmpdir"
  trap - EXIT

  print -r -- ""
  ok "Pulled $count worktree(s)"
  (( failed > 0 )) && warn "$failed worktree(s) had issues"

  # Send notification
  if (( failed > 0 )); then
    notify "wt pull-all" "Completed: $count success, $failed failed"
  else
    notify "wt pull-all" "All $count worktrees updated"
  fi
}

cmd_sync() {
  local repo="${1:-}"; local branch="${2:-}"; local base="${3:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
    dim "  Detected: $repo / $branch"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to sync")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt sync [<repo> [<branch>]] [base]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  # Load repo-specific config (may override DEFAULT_BASE)
  load_repo_config "$git_dir"

  # Use provided base or default
  [[ -z "$base" ]] && base="$DEFAULT_BASE"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  info "Fetching latest..."
  git --git-dir="$git_dir" fetch --all --prune --quiet

  # Check for uncommitted changes
  if [[ -n "$(/usr/bin/git -C "$wt_path" status --porcelain 2>/dev/null)" ]]; then
    die "Worktree has uncommitted changes. Commit or stash them first."
  fi

  info "Rebasing ${C_MAGENTA}$branch${C_RESET} onto ${C_DIM}$base${C_RESET}..."
  GIT_SSH_COMMAND="/usr/bin/ssh" /usr/bin/git -C "$wt_path" rebase "$base"
  ok "Sync complete"

  # Run post-sync hooks
  local app_url; app_url="$(url_for "$repo" "$branch")"
  local db_name; db_name="$(db_name_for "$repo" "$branch")"
  run_hooks "post-sync" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"
}

cmd_prune() {
  local repo="${1:-}"
  [[ -n "$repo" ]] || die "Usage: wt prune <repo>"

  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  info "Pruning stale worktrees..."
  git --git-dir="$git_dir" worktree prune -v

  info "Looking for merged branches..."

  # Get list of branches that have been merged to staging/main
  local merged; merged="$(git --git-dir="$git_dir" branch --merged origin/staging 2>/dev/null | grep -v 'staging\|main\|master' | tr -d ' ')" || merged=""

  if [[ -n "$merged" ]]; then
    print -r -- ""
    warn "The following branches appear to be merged:"
    print -r -- "$merged" | while read -r b; do
      [[ -n "$b" ]] && print -r -- "  ${C_DIM}$b${C_RESET}"
    done
    print -r -- ""

    if [[ "$FORCE" == true ]]; then
      print -r -- "$merged" | while read -r b; do
        [[ -n "$b" ]] && git --git-dir="$git_dir" branch -D "$b" 2>/dev/null && ok "Deleted $b"
      done
    else
      dim "Run with -f to delete merged branches"
    fi
  else
    ok "No merged branches to clean up"
  fi

  ok "Prune complete"
}

cmd_log() {
  local repo="${1:-}"; local branch="${2:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt log [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  print -r -- ""
  print -r -- "${C_BOLD}Recent commits in ${C_MAGENTA}$branch${C_RESET} ${C_DIM}(vs $DEFAULT_BASE)${C_RESET}"
  print -r -- ""

  git -C "$wt_path" log --oneline --graph -n 20 "$DEFAULT_BASE"..HEAD 2>/dev/null || \
    git -C "$wt_path" log --oneline --graph -n 20

  print -r -- ""
}

cmd_diff() {
  local repo="${1:-}"; local branch="${2:-}"; local base="${3:-$DEFAULT_BASE}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
  fi

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to diff")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt diff [<repo> [<branch>]] [base]
       Run from within a worktree to auto-detect, or specify repo/branch.
       Default base: $DEFAULT_BASE"

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"

  ensure_bare_repo "$git_dir"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  # Fetch to ensure we have latest base
  info "Fetching latest..."
  git --git-dir="$git_dir" fetch --all --prune --quiet

  # Check if base exists
  if ! git -C "$wt_path" rev-parse --verify "$base" >/dev/null 2>&1; then
    die "Base branch '$base' not found. Try: origin/main, origin/staging, or origin/master"
  fi

  # Get stats
  local commits; commits="$(git -C "$wt_path" rev-list --count "$base"..HEAD 2>/dev/null)" || commits="?"
  local files; files="$(git -C "$wt_path" diff --stat "$base"..HEAD 2>/dev/null | tail -1)" || files=""

  print -r -- ""
  print -r -- "${C_BOLD}Diff: ${C_MAGENTA}$branch${C_RESET} ${C_DIM}vs${C_RESET} ${C_CYAN}$base${C_RESET}"
  print -r -- ""
  print -r -- "  ${C_DIM}Commits:${C_RESET} $commits"
  [[ -n "$files" ]] && print -r -- "  ${C_DIM}Summary:${C_RESET} $files"
  print -r -- ""

  # Show the diff
  git -C "$wt_path" diff "$base"..HEAD --stat

  print -r -- ""
  dim "  For full diff: git -C \"$wt_path\" diff $base..HEAD"
  dim "  For patch:     git -C \"$wt_path\" diff $base..HEAD > changes.patch"
  print -r -- ""
}
