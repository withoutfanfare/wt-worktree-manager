#!/usr/bin/env zsh
# utility.sh - Utility and maintenance commands

cmd_templates() {
  local template_name="${1:-}"

  if [[ -z "$template_name" ]]; then
    # List all templates
    print -r -- ""
    print -r -- "${C_BOLD}Available Templates${C_RESET}"
    print -r -- ""
    list_templates
    print -r -- ""
    print -r -- "${C_DIM}Usage: wt templates <name>  - Show template details${C_RESET}"
    print -r -- "${C_DIM}       wt add <repo> <branch> --template=<name>${C_RESET}"
    print -r -- ""
    return 0
  fi

  # Validate template name first (security: prevent path traversal)
  validate_template_name "$template_name"

  # Show specific template details
  local template_file="$WT_TEMPLATES_DIR/${template_name}.conf"

  if [[ ! -f "$template_file" ]]; then
    die "Template not found: $template_name
       Expected: $template_file"
  fi

  print -r -- ""
  print -r -- "${C_BOLD}Template: ${C_CYAN}$template_name${C_RESET}"
  print -r -- ""

  # Extract description
  local desc; desc="$(extract_template_desc "$template_file")"
  if [[ -n "$desc" ]]; then
    print -r -- "${C_DIM}Description:${C_RESET} $desc"
    print -r -- ""
  fi

  print -r -- "${C_DIM}File:${C_RESET} $template_file"
  print -r -- ""
  print -r -- "${C_BOLD}Settings:${C_RESET}"

  # Show all WT_SKIP_* settings
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" || "$key" =~ ^[[:space:]]*$ ]] && continue

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    case "$key" in
      WT_SKIP_*)
        value="${value#\"}"
        value="${value%\"}"
        value="${value%%#*}"
        value="${value%"${value##*[![:space:]]}"}"
        if [[ "$value" == "true" ]]; then
          print -r -- "  ${C_YELLOW}$key${C_RESET} = ${C_RED}true${C_RESET} (skipped)"
        else
          print -r -- "  ${C_GREEN}$key${C_RESET} = ${C_GREEN}false${C_RESET} (enabled)"
        fi
        ;;
    esac
  done < "$template_file"

  print -r -- ""
  print -r -- "${C_DIM}Usage: wt add <repo> <branch> --template=$template_name${C_RESET}"
  print -r -- ""
}

cmd_doctor() {
  print -r -- ""
  print -r -- "${C_BOLD}wt doctor${C_RESET}"
  print -r -- ""

  local issues=0

  # Check HERD_ROOT
  print -r -- "${C_BOLD}Configuration${C_RESET}"
  if [[ -d "$HERD_ROOT" ]]; then
    ok "HERD_ROOT: $HERD_ROOT"
  else
    warn "HERD_ROOT does not exist: $HERD_ROOT"
    issues=$((issues + 1))
  fi

  if [[ -d "$DB_BACKUP_DIR" ]]; then
    ok "DB_BACKUP_DIR: $DB_BACKUP_DIR"
  else
    dim "  DB_BACKUP_DIR does not exist (will be created on first backup): $DB_BACKUP_DIR"
  fi

  print -r -- ""
  print -r -- "${C_BOLD}Required Tools${C_RESET}"

  # Check git
  if command -v git >/dev/null 2>&1; then
    local git_version; git_version="$(git --version 2>/dev/null | head -1)"
    ok "git: $git_version"
  else
    warn "git: not found"
    issues=$((issues + 1))
  fi

  # Check composer
  if command -v composer >/dev/null 2>&1; then
    local composer_version; composer_version="$(composer --version 2>/dev/null | head -1)"
    ok "composer: $composer_version"
  else
    warn "composer: not found"
    issues=$((issues + 1))
  fi

  print -r -- ""
  print -r -- "${C_BOLD}Optional Tools${C_RESET}"

  # Check mysql
  if command -v mysql >/dev/null 2>&1; then
    local mysql_version; mysql_version="$(mysql --version 2>/dev/null | head -1)"
    ok "mysql: $mysql_version"

    # Test connection
    local mysql_cmd=(mysql -h "$DB_HOST" -u "$DB_USER")
    if [[ -n "$DB_PASSWORD" ]]; then
      mysql_cmd+=(-p"$DB_PASSWORD")
    fi
    if "${mysql_cmd[@]}" -e "SELECT 1" >/dev/null 2>&1; then
      ok "  MySQL connection: OK"
    else
      warn "  MySQL connection: FAILED (check DB_HOST, DB_USER, DB_PASSWORD)"
    fi
  else
    dim "  mysql: not found (database features disabled)"
  fi

  # Check herd
  if command -v herd >/dev/null 2>&1; then
    ok "herd: installed"
  else
    dim "  herd: not found (site securing disabled)"
  fi

  # Check fzf
  if command -v fzf >/dev/null 2>&1; then
    ok "fzf: installed"
  else
    dim "  fzf: not found (interactive selection disabled)"
  fi

  # Check editor
  if command -v "$DEFAULT_EDITOR" >/dev/null 2>&1; then
    ok "editor: $DEFAULT_EDITOR"
  else
    dim "  editor: $DEFAULT_EDITOR not found"
  fi

  print -r -- ""
  print -r -- "${C_BOLD}Config Files${C_RESET}"

  local config_file="${WT_CONFIG:-$HOME/.wtrc}"
  if [[ -f "$config_file" ]]; then
    ok "User config: $config_file"
  else
    dim "  User config: $config_file (not found)"
  fi

  if [[ -f "$HERD_ROOT/.wtconfig" ]]; then
    ok "Project config: $HERD_ROOT/.wtconfig"
  else
    dim "  Project config: $HERD_ROOT/.wtconfig (not found)"
  fi

  print -r -- ""
  print -r -- "${C_BOLD}Hooks${C_RESET}"

  if [[ -d "$WT_HOOKS_DIR" ]]; then
    ok "Hooks directory: $WT_HOOKS_DIR"

    # Check for post-add hook
    if [[ -x "$WT_HOOKS_DIR/post-add" ]]; then
      ok "  post-add: enabled"
    elif [[ -f "$WT_HOOKS_DIR/post-add" ]]; then
      warn "  post-add: exists but not executable"
    else
      dim "  post-add: not configured"
    fi

    # Check for post-add.d directory
    if [[ -d "$WT_HOOKS_DIR/post-add.d" ]]; then
      local hook_count; hook_count="$(ls -1 "$WT_HOOKS_DIR/post-add.d" 2>/dev/null | wc -l | tr -d ' ')" || hook_count=0
      if (( hook_count > 0 )); then
        ok "  post-add.d/: $hook_count script(s)"
      fi
    fi

    # Check for post-rm hook
    if [[ -x "$WT_HOOKS_DIR/post-rm" ]]; then
      ok "  post-rm: enabled"
    elif [[ -f "$WT_HOOKS_DIR/post-rm" ]]; then
      warn "  post-rm: exists but not executable"
    else
      dim "  post-rm: not configured"
    fi

    # Check for post-rm.d directory
    if [[ -d "$WT_HOOKS_DIR/post-rm.d" ]]; then
      local hook_count; hook_count="$(ls -1 "$WT_HOOKS_DIR/post-rm.d" 2>/dev/null | wc -l | tr -d ' ')" || hook_count=0
      if (( hook_count > 0 )); then
        ok "  post-rm.d/: $hook_count script(s)"
      fi
    fi
  else
    dim "  Hooks directory: $WT_HOOKS_DIR (not found)"
    dim "  Create hooks with: mkdir -p $WT_HOOKS_DIR"
  fi

  print -r -- ""
  if (( issues > 0 )); then
    warn "$issues issue(s) found"
  else
    ok "All checks passed!"
  fi
  print -r -- ""
}

cmd_cleanup_herd() {
  print -r -- ""
  print -r -- "${C_BOLD}Cleaning orphaned Herd configs${C_RESET}"
  print -r -- ""

  if ! command -v herd >/dev/null 2>&1; then
    die "Herd is not installed"
  fi

  local nginx_dir="$HERD_CONFIG/valet/Nginx"
  local cert_dir="$HERD_CONFIG/valet/Certificates"
  local orphaned=()
  local cleaned=0

  if [[ ! -d "$nginx_dir" ]]; then
    warn "Nginx config directory not found: $nginx_dir"
    return 1
  fi

  info "Scanning for orphaned configs..."

  # Find all nginx configs that look like worktree sites (contain --)
  for config in "$nginx_dir"/*--*.test(N); do
    [[ -f "$config" ]] || continue
    local site_name="${config:t}"  # e.g., scooda--feature-xyz.test
    local folder_name="${site_name%.test}"  # e.g., scooda--feature-xyz
    local wt_path="$HERD_ROOT/$folder_name"

    # Check if the worktree directory exists
    if [[ ! -d "$wt_path" ]]; then
      orphaned+=("$site_name")
    fi
  done

  if (( ${#orphaned[@]} == 0 )); then
    ok "No orphaned configs found"
    print -r -- ""
    return 0
  fi

  print -r -- ""
  warn "Found ${C_BOLD}${#orphaned[@]}${C_RESET}${C_YELLOW} orphaned config(s):${C_RESET}"
  for site in "${orphaned[@]}"; do
    print -r -- "  ${C_DIM}•${C_RESET} $site"
  done
  print -r -- ""

  if [[ "$FORCE" == false ]]; then
    print -n "${C_YELLOW}Remove these orphaned configs? [y/N]${C_RESET} "
    local response
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] || { dim "Aborted"; return 0; }
  fi

  print -r -- ""
  for site_name in "${orphaned[@]}"; do
    local folder_name="${site_name%.test}"
    info "Cleaning ${C_CYAN}$site_name${C_RESET}"

    # Remove nginx config
    local nginx_config="$nginx_dir/$site_name"
    if [[ -f "$nginx_config" ]]; then
      /bin/rm -f "$nginx_config" 2>/dev/null
    fi

    # Remove certificate files
    for ext in crt key csr conf; do
      local cert_file="$cert_dir/${site_name}.${ext}"
      if [[ -f "$cert_file" ]]; then
        /bin/rm -f "$cert_file" 2>/dev/null
      fi
    done

    cleaned=$((cleaned + 1))
  done

  # Restart nginx to apply changes
  info "Restarting Herd nginx..."
  herd restart >/dev/null 2>&1

  print -r -- ""
  ok "Cleaned ${C_BOLD}$cleaned${C_RESET} orphaned config(s)"
  print -r -- ""
}

cmd_unlock() {
  local repo="${1:-}"

  # Auto-detect from current directory if no args
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    dim "  Detected: $repo"
  fi

  if [[ -n "$repo" ]]; then
    # Unlock specific repo
    validate_name "$repo" "repository"
    local git_dir; git_dir="$(git_dir_for "$repo")"
    ensure_bare_repo "$git_dir"

    local worktrees_dir="$git_dir/worktrees"
    if [[ ! -d "$worktrees_dir" ]]; then
      dim "No worktrees directory found for $repo"
      return 0
    fi

    local count=0
    for lock_file in "$worktrees_dir"/*/index.lock(N); do
      if [[ -f "$lock_file" ]]; then
        local wt_name="${${lock_file:h}:t}"
        rm -f "$lock_file"
        ok "Removed lock: ${C_CYAN}$wt_name${C_RESET}"
        count=$((count + 1))
      fi
    done

    if (( count == 0 )); then
      ok "No stale lock files found for ${C_CYAN}$repo${C_RESET}"
    else
      ok "Removed ${C_BOLD}$count${C_RESET} lock file(s)"
    fi
  else
    # Unlock all repos
    info "Scanning all repositories..."
    local total=0

    for git_dir in "$HERD_ROOT"/*.git(N); do
      [[ -d "$git_dir" ]] || continue
      local repo_name="${${git_dir:t}%.git}"
      local worktrees_dir="$git_dir/worktrees"

      [[ -d "$worktrees_dir" ]] || continue

      for lock_file in "$worktrees_dir"/*/index.lock(N); do
        if [[ -f "$lock_file" ]]; then
          local wt_name="${${lock_file:h}:t}"
          rm -f "$lock_file"
          ok "Removed lock: ${C_CYAN}$repo_name${C_RESET} / ${C_MAGENTA}$wt_name${C_RESET}"
          total=$((total + 1))
        fi
      done
    done

    if (( total == 0 )); then
      ok "No stale lock files found"
    else
      ok "Removed ${C_BOLD}$total${C_RESET} lock file(s)"
    fi
  fi
}

# New command: repair - Scan for and fix common issues
cmd_repair() {
  local repo="${1:-}"

  if [[ -z "$repo" ]]; then
    # Repair all repos
    info "Scanning all repositories for issues..."
    for git_dir in "$HERD_ROOT"/*.git(N); do
      [[ -d "$git_dir" ]] || continue
      local repo_name="${${git_dir:t}%.git}"
      _repair_repo "$repo_name" "$git_dir"
    done
  else
    validate_name "$repo" "repository"
    local git_dir; git_dir="$(git_dir_for "$repo")"
    ensure_bare_repo "$git_dir"
    _repair_repo "$repo" "$git_dir"
  fi
}

_repair_repo() {
  local repo="$1"
  local git_dir="$2"

  print -r -- ""
  print -r -- "${C_BOLD}Repairing: ${C_CYAN}$repo${C_RESET}"
  print -r -- ""

  local fixed=0

  # 1. Prune orphaned worktrees
  info "Checking for orphaned worktrees..."
  local pruned; pruned="$(git --git-dir="$git_dir" worktree prune -v 2>&1)" || true
  if [[ -n "$pruned" && "$pruned" != *"Nothing to prune"* ]]; then
    print -r -- "$pruned" | while read -r line; do
      ok "  Pruned: $line"
    done
    fixed=$((fixed + 1))
  else
    dim "  No orphaned worktrees"
  fi

  # 2. Clean stale index locks
  info "Checking for stale index locks..."
  local locks_cleaned=0
  check_index_locks "$git_dir" "--auto-clean"
  locks_cleaned=$?
  if (( locks_cleaned > 0 )); then
    fixed=$((fixed + 1))
  else
    dim "  No stale locks"
  fi

  # 3. Check for missing .git files in worktrees
  info "Checking worktree integrity..."
  local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || true
  local wt_wt_path=""
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_path="${line#worktree }"
    elif [[ -z "$line" && -n "$wt_path" && "$wt_path" != *.git ]]; then
      if [[ -d "$wt_path" && ! -f "$wt_path/.git" ]]; then
        warn "  Missing .git file: ${path##*/}"
        dim "    May need to recreate worktree"
      fi
      wt_path=""
    fi
  done <<< "$out"

  print -r -- ""
  if (( fixed > 0 )); then
    ok "Fixed $fixed issue(s) in $repo"
  else
    ok "No issues found in $repo"
  fi
}

# Parallel commands

cmd_build_all() {
  local repo="${1:-}"

  # Multi-repo mode
  if [[ "${ALL_REPOS:-false}" == true ]]; then
    info "Building all worktrees across all repositories..."
    print -r -- ""

    for git_dir in "$HERD_ROOT"/*.git(N); do
      [[ -d "$git_dir" ]] || continue
      local repo_name="${${git_dir:t}%.git}"
      print -r -- "${C_BOLD}${C_CYAN}$repo_name${C_RESET}"
      _build_all_for_repo "$repo_name" "$git_dir"
      print -r -- ""
    done

    ok "Build complete across all repositories"
    notify "wt build-all" "Completed across all repos"
    return 0
  fi

  [[ -n "$repo" ]] || die "Usage: wt build-all <repo>
       Use --all-repos to build across all repositories."

  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  _build_all_for_repo "$repo" "$git_dir"
  notify "wt build-all" "Completed for $repo"
}

_build_all_for_repo() {
  local repo="$1"
  local git_dir="$2"

  # Collect worktrees
  local worktrees=()
  collect_worktrees "$git_dir" worktrees

  (( ${#worktrees[@]} > 0 )) || { dim "  No worktrees found."; return 0; }

  # Build operations list
  local operations=()
  for wt_entry in "${worktrees[@]}"; do
    local wt_path="${wt_entry%%|*}"
    local wt_branch="${wt_entry##*|}"
    if [[ -f "$wt_path/package.json" ]]; then
      operations+=("$wt_branch|cd '$wt_path' && npm run build")
    fi
  done

  if (( ${#operations[@]} > 0 )); then
    parallel_run report_results "${operations[@]}"
  else
    dim "  No worktrees with package.json"
  fi
}

cmd_exec_all() {
  local repo="${1:-}"

  # Multi-repo mode
  if [[ "${ALL_REPOS:-false}" == true ]]; then
    shift || true
    local cmd=("$@")
    (( ${#cmd[@]} > 0 )) || die "Usage: wt exec-all --all-repos <command...>"

    local cmd_str="${cmd[*]}"
    info "Executing '$cmd_str' across all repositories..."
    print -r -- ""

    for git_dir in "$HERD_ROOT"/*.git(N); do
      [[ -d "$git_dir" ]] || continue
      local repo_name="${${git_dir:t}%.git}"
      print -r -- "${C_BOLD}${C_CYAN}$repo_name${C_RESET}"
      _exec_all_for_repo "$repo_name" "$git_dir" "$cmd_str"
      print -r -- ""
    done

    ok "Execution complete across all repositories"
    return 0
  fi

  shift || true
  local cmd=("$@")

  [[ -n "$repo" && ${#cmd[@]} -gt 0 ]] || die "Usage: wt exec-all <repo> <command...>
       Use --all-repos to execute across all repositories."

  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  _exec_all_for_repo "$repo" "$git_dir" "${cmd[*]}"
}

_exec_all_for_repo() {
  local repo="$1"
  local git_dir="$2"
  local cmd_str="$3"

  # Collect worktrees
  local worktrees=()
  collect_worktrees "$git_dir" worktrees

  (( ${#worktrees[@]} > 0 )) || { dim "  No worktrees found."; return 0; }

  # Build operations list
  local operations=()
  for wt_entry in "${worktrees[@]}"; do
    local wt_path="${wt_entry%%|*}"
    local wt_branch="${wt_entry##*|}"
    operations+=("$wt_branch|cd '$wt_path' && $cmd_str")
  done

  parallel_run report_results "${operations[@]}"
}

# ============================================================================
# New commands: upgrade, info, recent, clean, alias
# ============================================================================

cmd_upgrade() {
  print -r -- ""
  print -r -- "${C_BOLD}wt upgrade${C_RESET}"
  print -r -- ""

  # Find the wt script location
  local wt_path; wt_path="$(command -v wt 2>/dev/null)"
  if [[ -z "$wt_path" ]]; then
    die "Cannot find wt in PATH"
  fi

  # Resolve symlink to find repo
  local real_path; real_path="$(readlink "$wt_path" 2>/dev/null || echo "$wt_path")"
  local repo_dir="${real_path:h}"

  # Check if it's a git repo
  if [[ ! -d "$repo_dir/.git" && ! -f "$repo_dir/.git" ]]; then
    # Try parent directory
    repo_dir="${repo_dir:h}"
    if [[ ! -d "$repo_dir/.git" && ! -f "$repo_dir/.git" ]]; then
      die "wt is not installed from a git repository. Cannot upgrade."
    fi
  fi

  info "Repository: ${C_CYAN}$repo_dir${C_RESET}"

  # Check current version
  local current_version="$VERSION"
  info "Current version: ${C_YELLOW}v$current_version${C_RESET}"

  # Fetch latest
  info "Fetching updates..."
  if ! git -C "$repo_dir" fetch origin --quiet 2>/dev/null; then
    die "Failed to fetch updates. Check your network connection."
  fi

  # Check if we're behind
  local local_head; local_head="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)"
  local remote_head; remote_head="$(git -C "$repo_dir" rev-parse origin/main 2>/dev/null || git -C "$repo_dir" rev-parse origin/master 2>/dev/null)"

  if [[ "$local_head" == "$remote_head" ]]; then
    ok "Already up to date!"
    print -r -- ""
    return 0
  fi

  # Show what's new
  local commits_behind; commits_behind="$(git -C "$repo_dir" rev-list --count HEAD..origin/main 2>/dev/null || git -C "$repo_dir" rev-list --count HEAD..origin/master 2>/dev/null || echo 0)"
  info "Updates available: ${C_GREEN}$commits_behind${C_RESET} new commit(s)"
  print -r -- ""

  # Show recent commits
  dim "Recent changes:"
  git -C "$repo_dir" log --oneline HEAD..origin/main 2>/dev/null | head -5 | while read -r line; do
    print -r -- "  ${C_DIM}•${C_RESET} $line"
  done
  print -r -- ""

  # Confirm upgrade
  if [[ "$FORCE" != true ]]; then
    print -n "${C_YELLOW}Upgrade now? [y/N]${C_RESET} "
    local response
    read -r response
    [[ "$response" =~ ^[Yy]$ ]] || { dim "Aborted"; return 0; }
  fi

  # Pull updates
  info "Pulling updates..."
  if ! git -C "$repo_dir" pull --rebase origin main 2>/dev/null && ! git -C "$repo_dir" pull --rebase origin master 2>/dev/null; then
    die "Failed to pull updates. You may need to resolve conflicts manually."
  fi

  # Rebuild if build.sh exists
  if [[ -x "$repo_dir/build.sh" ]]; then
    info "Rebuilding..."
    if ! "$repo_dir/build.sh" >/dev/null 2>&1; then
      warn "Build failed. Try running ./build.sh manually."
    fi
  fi

  # Show new version
  local new_version
  if [[ -f "$repo_dir/lib/00-header.sh" ]]; then
    new_version="$(grep '^VERSION=' "$repo_dir/lib/00-header.sh" 2>/dev/null | cut -d'"' -f2)"
  elif [[ -f "$repo_dir/wt" ]]; then
    new_version="$(grep '^VERSION=' "$repo_dir/wt" 2>/dev/null | head -1 | cut -d'"' -f2)"
  fi
  new_version="${new_version:-unknown}"

  print -r -- ""
  ok "Upgraded: ${C_YELLOW}v$current_version${C_RESET} → ${C_GREEN}v$new_version${C_RESET}"
  print -r -- ""

  # Verify
  dim "Verify with: wt --version"
  print -r -- ""
}

cmd_version_check() {
  print -r -- ""
  print -r -- "${C_BOLD}Checking for updates...${C_RESET}"
  print -r -- ""

  local current_version="$VERSION"
  info "Installed: ${C_YELLOW}v$current_version${C_RESET}"

  # Find repo directory
  local wt_path; wt_path="$(command -v wt 2>/dev/null)"
  local real_path; real_path="$(readlink "$wt_path" 2>/dev/null || echo "$wt_path")"
  local repo_dir="${real_path:h}"

  if [[ ! -d "$repo_dir/.git" && ! -f "$repo_dir/.git" ]]; then
    repo_dir="${repo_dir:h}"
  fi

  if [[ -d "$repo_dir/.git" || -f "$repo_dir/.git" ]]; then
    # Fetch and check
    git -C "$repo_dir" fetch origin --quiet 2>/dev/null || true

    local local_head; local_head="$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)"
    local remote_head; remote_head="$(git -C "$repo_dir" rev-parse origin/main 2>/dev/null || git -C "$repo_dir" rev-parse origin/master 2>/dev/null)"

    if [[ "$local_head" == "$remote_head" ]]; then
      ok "You're running the latest version!"
    else
      local commits_behind; commits_behind="$(git -C "$repo_dir" rev-list --count HEAD..origin/main 2>/dev/null || git -C "$repo_dir" rev-list --count HEAD..origin/master 2>/dev/null || echo "?")"
      warn "Update available: ${C_GREEN}$commits_behind${C_RESET} new commit(s)"
      dim "  Run: wt upgrade"
    fi
  else
    dim "Cannot check for updates (not installed from git)"
  fi

  print -r -- ""
}

cmd_info() {
  local repo="${1:-}"
  local branch="${2:-}"

  # Auto-detect from current directory
  if [[ -z "$repo" ]] && detect_current_worktree; then
    repo="$DETECTED_REPO"
    branch="$DETECTED_BRANCH"
    dim "  Detected: $repo / $branch"
  fi

  [[ -n "$repo" ]] || die "Usage: wt info <repo> [branch]"
  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  # If no branch specified, use fzf or error
  if [[ -z "$branch" ]]; then
    if command -v fzf >/dev/null 2>&1; then
      branch="$(select_worktree "$git_dir")" || return 1
    else
      die "Branch required. Usage: wt info <repo> <branch>"
    fi
  fi

  validate_name "$branch" "branch"

  local wt_path; wt_path="$(wt_path_for "$repo" "$branch")"

  if [[ ! -d "$wt_path" ]]; then
    die "Worktree not found: $wt_path"
  fi

  print -r -- ""
  print -r -- "${C_BOLD}Worktree Info: ${C_CYAN}$repo${C_RESET} / ${C_MAGENTA}$branch${C_RESET}"
  print -r -- ""

  # Basic info
  print -r -- "${C_BOLD}Location${C_RESET}"
  print -r -- "  Path:     ${C_CYAN}$wt_path${C_RESET}"
  local url; url="$(url_for "$repo" "$branch")"
  print -r -- "  URL:      ${C_BLUE}$url${C_RESET}"
  local db_name; db_name="$(db_name_for "$repo" "$branch")"
  print -r -- "  Database: ${C_YELLOW}$db_name${C_RESET}"
  print -r -- ""

  # Git info
  print -r -- "${C_BOLD}Git${C_RESET}"
  local sha; sha="$(git -C "$wt_path" rev-parse HEAD 2>/dev/null)"
  local short_sha; short_sha="$(git -C "$wt_path" rev-parse --short HEAD 2>/dev/null)"
  print -r -- "  Commit:   ${C_DIM}$short_sha${C_RESET}"

  local last_msg; last_msg="$(git -C "$wt_path" log -1 --format='%s' 2>/dev/null | cut -c1-60)"
  print -r -- "  Message:  ${C_DIM}$last_msg${C_RESET}"

  local last_date; last_date="$(git -C "$wt_path" log -1 --format='%ar' 2>/dev/null)"
  print -r -- "  Date:     ${C_DIM}$last_date${C_RESET}"

  local author; author="$(git -C "$wt_path" log -1 --format='%an' 2>/dev/null)"
  print -r -- "  Author:   ${C_DIM}$author${C_RESET}"

  # Sync status
  local counts; counts="$(get_ahead_behind "$wt_path" "$DEFAULT_BASE")"
  local ahead="${counts%% *}" behind="${counts##* }"
  print -r -- "  Sync:     ${C_GREEN}↑$ahead${C_RESET} ${C_RED}↓$behind${C_RESET} vs $DEFAULT_BASE"
  print -r -- ""

  # Working tree status
  print -r -- "${C_BOLD}Status${C_RESET}"
  local st; st="$(git -C "$wt_path" status --porcelain 2>/dev/null)"
  if [[ -n "$st" ]]; then
    local changes; changes="$(print -r -- "$st" | wc -l | tr -d ' ')"
    local staged; staged="$(print -r -- "$st" | grep -c '^[MADRC]' || echo 0)"
    local unstaged; unstaged="$(print -r -- "$st" | grep -c '^.[MADRC]' || echo 0)"
    local untracked; untracked="$(print -r -- "$st" | grep -c '^??' || echo 0)"
    print -r -- "  Changes:  ${C_YELLOW}$changes${C_RESET} total"
    print -r -- "  Staged:   ${C_GREEN}$staged${C_RESET}"
    print -r -- "  Modified: ${C_YELLOW}$unstaged${C_RESET}"
    print -r -- "  Untracked: ${C_DIM}$untracked${C_RESET}"
  else
    print -r -- "  Status:   ${C_GREEN}● Clean${C_RESET}"
  fi
  print -r -- ""

  # Disk usage
  print -r -- "${C_BOLD}Disk Usage${C_RESET}"
  local total_size; total_size="$(du -sh "$wt_path" 2>/dev/null | cut -f1)"
  print -r -- "  Total:        ${C_YELLOW}$total_size${C_RESET}"

  if [[ -d "$wt_path/node_modules" ]]; then
    local nm_size; nm_size="$(du -sh "$wt_path/node_modules" 2>/dev/null | cut -f1)"
    print -r -- "  node_modules: ${C_DIM}$nm_size${C_RESET}"
  fi
  if [[ -d "$wt_path/vendor" ]]; then
    local vendor_size; vendor_size="$(du -sh "$wt_path/vendor" 2>/dev/null | cut -f1)"
    print -r -- "  vendor:       ${C_DIM}$vendor_size${C_RESET}"
  fi
  print -r -- ""

  # Framework detection
  print -r -- "${C_BOLD}Framework${C_RESET}"
  if [[ -f "$wt_path/artisan" ]]; then
    local laravel_version; laravel_version="$(grep -m1 'laravel/framework' "$wt_path/composer.lock" 2>/dev/null | grep -o '"version": "[^"]*"' | cut -d'"' -f4)"
    print -r -- "  Laravel:  ${C_GREEN}$laravel_version${C_RESET}"
  fi
  if [[ -f "$wt_path/package.json" ]]; then
    local node_deps; node_deps="$(jq '.dependencies | length' "$wt_path/package.json" 2>/dev/null || echo "?")"
    print -r -- "  Node:     ${C_DIM}$node_deps dependencies${C_RESET}"
  fi
  print -r -- ""
}

cmd_recent() {
  local limit="${1:-5}"

  print -r -- ""
  print -r -- "${C_BOLD}Recently Accessed Worktrees${C_RESET}"
  print -r -- ""

  # Find all worktrees and sort by access time
  local worktrees=()

  # Declare loop-scoped variables BEFORE the loop to avoid zsh local re-declaration bug
  local repo_name out wt_path line atime
  local entry rest repo folder branch now age age_str

  for git_dir in "$HERD_ROOT"/*.git(N); do
    [[ -d "$git_dir" ]] || continue
    repo_name="${${git_dir:t}%.git}"

    out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || continue
    wt_path=""

    while IFS= read -r line; do
      if [[ "$line" == worktree\ * ]]; then
        wt_path="${line#worktree }"
      elif [[ -z "$line" && -n "$wt_path" && "$wt_path" != *.git && -d "$wt_path" ]]; then
        atime="$(stat -f '%m' "$wt_path" 2>/dev/null || stat -c '%Y' "$wt_path" 2>/dev/null || echo 0)"
        worktrees+=("$atime|$repo_name|$wt_path")
        wt_path=""
      fi
    done <<< "$out"
    # Handle last entry (no trailing newline in porcelain output)
    if [[ -n "$wt_path" && "$wt_path" != *.git && -d "$wt_path" ]]; then
      atime="$(stat -f '%m' "$wt_path" 2>/dev/null || stat -c '%Y' "$wt_path" 2>/dev/null || echo 0)"
      worktrees+=("$atime|$repo_name|$wt_path")
    fi
  done

  if (( ${#worktrees[@]} == 0 )); then
    dim "No worktrees found."
    return 0
  fi

  # Sort by access time (newest first) and show top N
  local sorted
  sorted=($(printf '%s\n' "${worktrees[@]}" | sort -t'|' -k1 -rn | head -n "$limit"))

  local idx=0
  for entry in "${sorted[@]}"; do
    idx=$((idx + 1))
    atime="${entry%%|*}"
    rest="${entry#*|}"
    repo="${rest%%|*}"
    wt_path="${rest#*|}"
    folder="${wt_path:t}"
    branch="${folder#*--}"

    # Format time
    now="$(date +%s)"
    age=$((now - atime))
    if (( age < 3600 )); then
      age_str="$((age / 60))m ago"
    elif (( age < 86400 )); then
      age_str="$((age / 3600))h ago"
    else
      age_str="$((age / 86400))d ago"
    fi

    print -r -- "  ${C_BOLD}[$idx]${C_RESET} ${C_CYAN}$repo${C_RESET} / ${C_MAGENTA}$branch${C_RESET}"
    print -r -- "      ${C_DIM}$age_str${C_RESET}"
  done

  print -r -- ""
  dim "Usage: cd \"\$(wt cd <repo> <branch>)\""
  print -r -- ""
}

cmd_clean() {
  local repo="${1:-}"
  local dry_run="${DRY_RUN:-false}"

  print -r -- ""
  print -r -- "${C_BOLD}Clean Inactive Worktrees${C_RESET}"
  print -r -- ""

  local inactive_days=30
  local total_saved=0
  local cleaned=0

  # Helper to format bytes
  format_size() {
    local bytes="$1"
    if (( bytes >= 1073741824 )); then
      printf "%.1fG" "$((bytes / 1073741824.0))"
    elif (( bytes >= 1048576 )); then
      printf "%.1fM" "$((bytes / 1048576.0))"
    elif (( bytes >= 1024 )); then
      printf "%.1fK" "$((bytes / 1024.0))"
    else
      printf "%dB" "$bytes"
    fi
  }

  process_repo() {
    local repo_name="$1"
    local git_dir; git_dir="$(git_dir_for "$repo_name")"

    local out; out="$(git --git-dir="$git_dir" worktree list --porcelain 2>/dev/null)" || return
    local wt_path="" branch="" line=""
    local age_days nm_size vendor_size wt_saved folder nm_human v_human

    while IFS= read -r line; do
      if [[ "$line" == worktree\ * ]]; then
        wt_path="${line#worktree }"
      elif [[ "$line" == branch\ refs/heads/* ]]; then
        branch="${line#branch refs/heads/}"
      elif [[ -z "$line" && -n "$wt_path" && "$wt_path" != *.git ]]; then
        if [[ -d "$wt_path" ]]; then
          age_days="$(get_commit_age_days "$wt_path")"

          if (( age_days > inactive_days )); then
            nm_size=0
            vendor_size=0
            wt_saved=0

            # Check node_modules
            if [[ -d "$wt_path/node_modules" ]]; then
              nm_size="$(du -sk "$wt_path/node_modules" 2>/dev/null | cut -f1)"
              nm_size=$((nm_size * 1024))  # Convert to bytes
            fi

            # Check vendor
            if [[ -d "$wt_path/vendor" ]]; then
              vendor_size="$(du -sk "$wt_path/vendor" 2>/dev/null | cut -f1)"
              vendor_size=$((vendor_size * 1024))
            fi

            wt_saved=$((nm_size + vendor_size))

            if (( wt_saved > 0 )); then
              folder="${wt_path:t}"
              print -r -- "  ${C_CYAN}$repo_name${C_RESET} / ${C_MAGENTA}${folder#*--}${C_RESET}"
              print -r -- "    ${C_DIM}Inactive: ${age_days}d${C_RESET}"

              if (( nm_size > 0 )); then
                nm_human="$(format_size $nm_size)"
                print -r -- "    ${C_DIM}node_modules:${C_RESET} ${C_YELLOW}$nm_human${C_RESET}"
              fi
              if (( vendor_size > 0 )); then
                v_human="$(format_size $vendor_size)"
                print -r -- "    ${C_DIM}vendor:${C_RESET}       ${C_YELLOW}$v_human${C_RESET}"
              fi

              if [[ "$dry_run" != true ]]; then
                [[ -d "$wt_path/node_modules" ]] && rm -rf "$wt_path/node_modules"
                [[ -d "$wt_path/vendor" ]] && rm -rf "$wt_path/vendor"
              fi

              total_saved=$((total_saved + wt_saved))
              cleaned=$((cleaned + 1))
              print -r -- ""
            fi
          fi
        fi
        wt_path=""
        branch=""
      fi
    done <<< "$out"
  }

  # Declare loop-scoped variables
  local repo_name total_human

  if [[ -n "$repo" ]]; then
    validate_name "$repo" "repository"
    process_repo "$repo"
  else
    # Process all repos
    for git_dir in "$HERD_ROOT"/*.git(N); do
      [[ -d "$git_dir" ]] || continue
      repo_name="${${git_dir:t}%.git}"
      process_repo "$repo_name"
    done
  fi

  if (( cleaned == 0 )); then
    ok "No inactive worktrees with cleanable dependencies found"
  else
    total_human="$(format_size $total_saved)"
    if [[ "$dry_run" == true ]]; then
      info "Would clean ${C_BOLD}$cleaned${C_RESET} worktree(s), saving ${C_GREEN}$total_human${C_RESET}"
      dim "  Run without --dry-run to clean"
    else
      ok "Cleaned ${C_BOLD}$cleaned${C_RESET} worktree(s), saved ${C_GREEN}$total_human${C_RESET}"
      dim "  Reinstall with: npm ci / composer install"
    fi
  fi
  print -r -- ""
}

# Alias management
readonly WT_ALIASES_FILE="$HOME/.wt/aliases"

cmd_alias() {
  local action="${1:-}"
  local alias_name="${2:-}"
  local target="${3:-}"

  # Ensure aliases file exists
  [[ -d "${WT_ALIASES_FILE:h}" ]] || mkdir -p "${WT_ALIASES_FILE:h}"
  [[ -f "$WT_ALIASES_FILE" ]] || touch "$WT_ALIASES_FILE"

  case "$action" in
    ""|list)
      print -r -- ""
      print -r -- "${C_BOLD}Branch Aliases${C_RESET}"
      print -r -- ""
      if [[ -s "$WT_ALIASES_FILE" ]]; then
        while IFS='=' read -r name value; do
          [[ -n "$name" && "$name" != \#* ]] && print -r -- "  ${C_GREEN}$name${C_RESET} → ${C_MAGENTA}$value${C_RESET}"
        done < "$WT_ALIASES_FILE"
      else
        dim "  No aliases defined"
      fi
      print -r -- ""
      dim "Usage: wt alias add <name> <repo/branch>"
      dim "       wt alias rm <name>"
      print -r -- ""
      ;;

    add|set)
      [[ -n "$alias_name" && -n "$target" ]] || die "Usage: wt alias add <name> <repo/branch>"

      # Validate alias name (alphanumeric, dash, underscore only)
      if [[ ! "$alias_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Invalid alias name: '$alias_name' (use alphanumeric, dash, underscore)"
      fi

      # Remove existing alias if present
      if grep -q "^${alias_name}=" "$WT_ALIASES_FILE" 2>/dev/null; then
        local temp_file; temp_file="$(mktemp)"
        grep -v "^${alias_name}=" "$WT_ALIASES_FILE" > "$temp_file"
        mv "$temp_file" "$WT_ALIASES_FILE"
      fi

      # Add new alias
      print -r -- "${alias_name}=${target}" >> "$WT_ALIASES_FILE"
      ok "Alias created: ${C_GREEN}$alias_name${C_RESET} → ${C_MAGENTA}$target${C_RESET}"
      ;;

    rm|remove|delete)
      [[ -n "$alias_name" ]] || die "Usage: wt alias rm <name>"

      if grep -q "^${alias_name}=" "$WT_ALIASES_FILE" 2>/dev/null; then
        local temp_file; temp_file="$(mktemp)"
        grep -v "^${alias_name}=" "$WT_ALIASES_FILE" > "$temp_file"
        mv "$temp_file" "$WT_ALIASES_FILE"
        ok "Alias removed: ${C_YELLOW}$alias_name${C_RESET}"
      else
        die "Alias not found: $alias_name"
      fi
      ;;

    *)
      die "Unknown action: $action (try: list, add, rm)"
      ;;
  esac
}

# Resolve alias to repo/branch
resolve_alias() {
  local alias_name="$1"

  if [[ -f "$WT_ALIASES_FILE" ]]; then
    local result; result="$(grep "^${alias_name}=" "$WT_ALIASES_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)"
    if [[ -n "$result" ]]; then
      print -r -- "$result"
      return 0
    fi
  fi
  return 1
}
