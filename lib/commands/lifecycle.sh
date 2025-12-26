#!/usr/bin/env zsh
# lifecycle.sh - Worktree creation and removal commands

cmd_add() {
  local repo="${1:-}"; local branch="${2:-}"; local base="${3:-}"
  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt add <repo> <branch> [base]"

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  # Load repo-specific config (may override DEFAULT_BASE)
  load_repo_config "$git_dir"

  # Load template if specified (sets WT_SKIP_* environment variables)
  if [[ -n "$WT_TEMPLATE" ]]; then
    load_template "$WT_TEMPLATE"
  fi

  # Use provided base or default
  [[ -z "$base" ]] && base="$DEFAULT_BASE"

  local wt_path; wt_path="$(wt_path_for "$repo" "$branch")"
  local app_url; app_url="$(url_for "$repo" "$branch")"
  local db_name; db_name="$(db_name_for "$repo" "$branch")"

  # Dry-run mode - show what would happen without executing
  if [[ "$DRY_RUN" == true ]]; then
    print -r -- ""
    print -r -- "${C_BOLD}Dry Run Preview${C_RESET}"
    print -r -- ""
    print -r -- "${C_BOLD}Worktree Details:${C_RESET}"
    print -r -- "  Repository:  ${C_CYAN}$repo${C_RESET}"
    print -r -- "  Branch:      ${C_MAGENTA}$branch${C_RESET}"
    print -r -- "  Base:        ${C_DIM}$base${C_RESET}"
    print -r -- "  Path:        $wt_path"
    print -r -- "  URL:         ${C_CYAN}$app_url${C_RESET}"
    print -r -- "  Database:    ${C_CYAN}$db_name${C_RESET}"
    print -r -- ""
    if [[ -n "$WT_TEMPLATE" ]]; then
      print -r -- "${C_BOLD}Template:${C_RESET} $WT_TEMPLATE"
      print -r -- "  ${C_DIM}WT_SKIP_DB${C_RESET}=${WT_SKIP_DB:-false}"
      print -r -- "  ${C_DIM}WT_SKIP_COMPOSER${C_RESET}=${WT_SKIP_COMPOSER:-false}"
      print -r -- "  ${C_DIM}WT_SKIP_NPM${C_RESET}=${WT_SKIP_NPM:-false}"
      print -r -- "  ${C_DIM}WT_SKIP_BUILD${C_RESET}=${WT_SKIP_BUILD:-false}"
      print -r -- "  ${C_DIM}WT_SKIP_MIGRATE${C_RESET}=${WT_SKIP_MIGRATE:-false}"
      print -r -- "  ${C_DIM}WT_SKIP_HERD${C_RESET}=${WT_SKIP_HERD:-false}"
      print -r -- ""
    fi
    print -r -- "${C_BOLD}Actions:${C_RESET}"
    print -r -- "  1. Fetch latest branches from remote"
    if git --git-dir="$git_dir" show-ref --quiet "refs/heads/$branch" 2>/dev/null; then
      print -r -- "  2. Create worktree from existing branch: $branch"
    else
      print -r -- "  2. Create new branch '$branch' from '$base'"
      print -r -- "  3. Push branch to remote and set up tracking"
    fi
    print -r -- "  4. Run pre-add hooks"
    print -r -- "  5. Run post-add hooks (environment setup)"
    print -r -- ""
    print -r -- "${C_DIM}Run without --dry-run to execute${C_RESET}"
    return 0
  fi

  info "Fetching latest branches..."
  git --git-dir="$git_dir" fetch --all --prune --quiet

  # If base is a remote ref (origin/...), explicitly fetch it to ensure we have the latest
  if [[ "$base" == origin/* ]]; then
    local remote_branch="${base#origin/}"
    dim "  Fetching latest: $remote_branch"
    git --git-dir="$git_dir" fetch origin "$remote_branch:refs/remotes/origin/$remote_branch" --force 2>/dev/null || true
  fi

  [[ ! -d "$wt_path" ]] || die "Worktree already exists at ${C_CYAN}$wt_path${C_RESET}"

  # Verify base branch exists when creating new branch
  if ! git --git-dir="$git_dir" show-ref --quiet "refs/heads/$branch"; then
    if ! git --git-dir="$git_dir" rev-parse --verify "$base" >/dev/null 2>&1; then
      die "Base branch '$base' not found. Run: git --git-dir=\"$git_dir\" branch -a"
    fi
  fi

  # Run pre-add hooks (can abort by returning non-zero)
  if ! run_hooks "pre-add" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"; then
    die "Pre-add hook failed - aborting"
  fi

  # Setup cleanup trap for failed operations
  local cleanup_needed=true
  trap '[[ "$cleanup_needed" == true ]] && { warn "Cleaning up failed worktree..."; git --git-dir="$git_dir" worktree remove --force "$wt_path" 2>/dev/null; }' EXIT

  if git --git-dir="$git_dir" show-ref --quiet "refs/heads/$branch"; then
    info "Creating worktree from existing branch: ${C_MAGENTA}$branch${C_RESET}"
    git --git-dir="$git_dir" worktree add "$wt_path" "$branch"
  else
    info "Creating branch ${C_MAGENTA}$branch${C_RESET} from ${C_DIM}$base${C_RESET}"
    git --git-dir="$git_dir" worktree add --no-track -b "$branch" "$wt_path" "$base"
  fi

  # Set up proper remote tracking for the branch
  info "Setting up remote tracking for ${C_MAGENTA}$branch${C_RESET}"
  if GIT_SSH_COMMAND="/usr/bin/ssh" /usr/bin/git -C "$wt_path" push -u origin "$branch:$branch" 2>/dev/null; then
    ok "Remote branch created and tracking set"
  else
    dim "  Push failed (may need to push manually later): git push -u origin $branch"
  fi

  # Success - disable cleanup trap
  cleanup_needed=false
  trap - EXIT

  # Run post-add hooks
  run_hooks "post-add" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"

  if [[ "$JSON_OUTPUT" == true ]]; then
    print -r -- "{\"path\": \"$(json_escape "$wt_path")\", \"url\": \"$(json_escape "$app_url")\", \"branch\": \"$(json_escape "$branch")\", \"database\": \"$(json_escape "$db_name")\"}"
  else
    print -r -- ""
    ok "${C_BOLD}Worktree ready${C_RESET}"
    print -r -- "   ${C_DIM}Path${C_RESET}  $wt_path"
    print -r -- "   ${C_DIM}URL${C_RESET}   ${C_CYAN}$app_url${C_RESET}"
    print -r -- "   ${C_DIM}DB${C_RESET}    ${C_CYAN}$db_name${C_RESET}"
    print -r -- ""
  fi
}

cmd_rm() {
  local repo="${1:-}"; local branch="${2:-}"

  # Handle fzf selection if branch not provided
  if [[ -n "$repo" && -z "$branch" ]] && command -v fzf >/dev/null 2>&1; then
    validate_name "$repo" "repository"
    branch="$(select_branch_fzf "$repo" "Select worktree to remove")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt rm [-f] [--delete-branch] <repo> <branch>"

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  local app_url; app_url="$(url_for "$repo" "$branch")"
  local db_name; db_name="$(db_name_for "$repo" "$branch")"
  local site_name="${wt_path:t}"

  ensure_bare_repo "$git_dir"
  [[ -d "$wt_path" ]] || die "Worktree not found at $wt_path"

  # Branch protection check
  if is_protected_branch "$branch" && [[ "$FORCE" == false ]]; then
    die "Branch '$branch' is protected. Use -f to force removal."
  fi

  # Check for uncommitted changes and confirm (unless --force)
  if [[ "$FORCE" == false ]]; then
    local wt_status; wt_status="$(git -C "$wt_path" status --porcelain 2>/dev/null)" || wt_status=""
    if [[ -n "$wt_status" ]]; then
      local changes; changes="$(print -r -- "$wt_status" | wc -l | tr -d ' ')"
      warn "Worktree has ${C_BOLD}$changes${C_RESET}${C_YELLOW} uncommitted change(s):${C_RESET}"
      git -C "$wt_path" status --short
      print -n "${C_YELLOW}Continue with removal? [y/N]${C_RESET} "
      local response
      read -r response
      [[ "$response" =~ ^[Yy]$ ]] || die "Aborted"
    fi
  fi

  # Run pre-rm hooks
  if ! run_hooks "pre-rm" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"; then
    die "Pre-rm hook failed - aborting"
  fi

  info "Removing worktree ${C_CYAN}$wt_path${C_RESET}"
  if [[ "$FORCE" == true ]]; then
    git --git-dir="$git_dir" worktree remove --force "$wt_path"
  else
    git --git-dir="$git_dir" worktree remove "$wt_path"
  fi

  # Delete branch if requested
  if [[ "$DELETE_BRANCH" == true ]]; then
    info "Deleting branch ${C_MAGENTA}$branch${C_RESET}"
    git --git-dir="$git_dir" branch -D "$branch" 2>/dev/null || warn "Could not delete branch (may not exist locally)"
  fi

  info "Pruning stale worktrees..."
  git --git-dir="$git_dir" worktree prune

  # Run post-rm hooks
  run_hooks "post-rm" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"

  ok "Worktree removed"
  print -r -- ""
}

cmd_clone() {
  local url="${1:-}"; local repo="${2:-}"; local initial_branch="${3:-}"
  [[ -n "$url" ]] || die "Usage: wt clone <url> [repo-name] [branch]"

  # Extract repo name from URL if not provided
  if [[ -z "$repo" ]]; then
    repo="${url##*/}"
    repo="${repo%.git}"
  fi

  validate_name "$repo" "repository"
  [[ -z "$initial_branch" ]] || validate_name "$initial_branch" "branch"

  local git_dir; git_dir="$(git_dir_for "$repo")"

  [[ ! -d "$git_dir" ]] || die "Bare repo already exists at $git_dir"

  info "Cloning ${C_CYAN}$url${C_RESET} as bare repo..."
  GIT_SSH_COMMAND="/usr/bin/ssh" /usr/bin/git clone --bare "$url" "$git_dir"

  # Configure fetch to get all branches
  /usr/bin/git --git-dir="$git_dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

  info "Fetching all branches..."
  GIT_SSH_COMMAND="/usr/bin/ssh" /usr/bin/git --git-dir="$git_dir" fetch --all --prune

  print -r -- ""
  ok "Bare repo created at ${C_CYAN}$git_dir${C_RESET}"

  # If specific branch requested, create worktree for it
  if [[ -n "$initial_branch" ]]; then
    print -r -- ""
    if /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/$initial_branch"; then
      info "Creating worktree for ${C_GREEN}$initial_branch${C_RESET}..."
      cmd_add "$repo" "$initial_branch" "origin/$initial_branch"
    else
      local base_branch=""
      if /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/staging"; then
        base_branch="origin/staging"
      elif /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/main"; then
        base_branch="origin/main"
      elif /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/master"; then
        base_branch="origin/master"
      else
        die "Branch '$initial_branch' not found on remote and no default base branch available"
      fi
      info "Creating new branch ${C_GREEN}$initial_branch${C_RESET} from $base_branch..."
      cmd_add "$repo" "$initial_branch" "$base_branch"
    fi
  elif /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/staging"; then
    print -r -- ""
    info "Found staging branch - creating worktree..."
    cmd_add "$repo" "staging" "origin/staging"
  elif /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/main"; then
    print -r -- ""
    info "Found main branch - creating worktree..."
    cmd_add "$repo" "main" "origin/main"
  elif /usr/bin/git --git-dir="$git_dir" show-ref --quiet "refs/remotes/origin/master"; then
    print -r -- ""
    info "Found master branch - creating worktree..."
    cmd_add "$repo" "master" "origin/master"
  else
    dim "  Create a worktree with: wt add $repo <branch>"
    print -r -- ""
  fi

  notify "wt clone" "Repository $repo cloned successfully"
}

cmd_fresh() {
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
    branch="$(select_branch_fzf "$repo" "Select worktree to refresh")" || die "No branch selected"
  fi

  [[ -n "$repo" && -n "$branch" ]] || die "Usage: wt fresh [<repo> [<branch>]]
       Run from within a worktree to auto-detect, or specify repo/branch."

  validate_name "$repo" "repository"
  validate_name "$branch" "branch"

  local wt_path; wt_path="$(resolve_wt_path "$repo" "$branch")"
  [[ -d "$wt_path" ]] || die_wt_not_found "$repo" "$wt_path"

  pushd "$wt_path" >/dev/null || die "Failed to cd into $wt_path"

  print -r -- ""
  print -r -- "${C_BOLD}Refreshing ${C_CYAN}$repo${C_RESET} / ${C_MAGENTA}$branch${C_RESET}"
  print -r -- ""

  # Run migrate:fresh --seed (with confirmation unless forced)
  if [[ -f "artisan" ]]; then
    if [[ "$FORCE" == false ]]; then
      warn "This will DROP ALL TABLES in the database!"
      print -n "${C_YELLOW}Continue with migrate:fresh? [y/N]${C_RESET} "
      local response
      read -r response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        warn "Skipping migrate:fresh"
        popd >/dev/null
        return 0
      fi
    fi

    info "Running migrate:fresh --seed..."
    if php artisan migrate:fresh --seed; then
      ok "Database refreshed"
    else
      warn "migrate:fresh --seed failed"
    fi
  fi

  # Run npm ci
  if [[ -f "package.json" ]]; then
    info "Running npm ci..."
    if npm ci; then
      ok "npm dependencies installed"
    else
      warn "npm ci failed"
    fi

    info "Running npm run build..."
    if npm run build; then
      ok "Assets built"
    else
      warn "npm run build failed"
    fi
  fi

  popd >/dev/null

  notify "wt fresh" "Completed for $repo / $branch"
  print -r -- ""
  ok "Fresh complete!"
  print -r -- ""
}
