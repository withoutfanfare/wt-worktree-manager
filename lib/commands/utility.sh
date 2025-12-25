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
  local desc; desc="$(grep '^TEMPLATE_DESC=' "$template_file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'")"
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
  local path=""
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      path="${line#worktree }"
    elif [[ -z "$line" && -n "$path" && "$path" != *.git ]]; then
      if [[ -d "$path" && ! -f "$path/.git" ]]; then
        warn "  Missing .git file: ${path##*/}"
        dim "    May need to recreate worktree"
      fi
      path=""
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
  [[ -n "$repo" ]] || die "Usage: wt build-all <repo>"

  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  # Collect worktrees
  local worktrees=()
  collect_worktrees "$git_dir" worktrees

  (( ${#worktrees[@]} > 0 )) || { dim "No worktrees found."; return 0; }

  # Build operations list
  local operations=()
  for wt_entry in "${worktrees[@]}"; do
    local wt_path="${wt_entry%%|*}"
    local wt_branch="${wt_entry##*|}"
    if [[ -f "$wt_path/package.json" ]]; then
      operations+=("$wt_branch|cd '$wt_path' && npm run build")
    fi
  done

  parallel_run report_results "${operations[@]}"
  notify "wt build-all" "Completed for $repo"
}

cmd_exec_all() {
  local repo="${1:-}"
  shift || true
  local cmd=("$@")

  [[ -n "$repo" && ${#cmd[@]} -gt 0 ]] || die "Usage: wt exec-all <repo> <command...>"

  validate_name "$repo" "repository"

  local git_dir; git_dir="$(git_dir_for "$repo")"
  ensure_bare_repo "$git_dir"

  # Collect worktrees
  local worktrees=()
  collect_worktrees "$git_dir" worktrees

  (( ${#worktrees[@]} > 0 )) || { dim "No worktrees found."; return 0; }

  # Build operations list
  local operations=()
  local cmd_str="${cmd[*]}"
  for wt_entry in "${worktrees[@]}"; do
    local wt_path="${wt_entry%%|*}"
    local wt_branch="${wt_entry##*|}"
    operations+=("$wt_branch|cd '$wt_path' && $cmd_str")
  done

  parallel_run report_results "${operations[@]}"
}
