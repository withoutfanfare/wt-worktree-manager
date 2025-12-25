#!/usr/bin/env zsh
# 06-hooks.sh - Hook system for extensible worktree setup

# Verify hook file is safe to execute (owned by current user, not world-writable)
verify_hook_security() {
  local hook_file="$1"
  local current_uid; current_uid="$(id -u)"

  # Check ownership (macOS stat format)
  local file_owner; file_owner="$(stat -f %u "$hook_file" 2>/dev/null)"
  if [[ "$file_owner" != "$current_uid" ]]; then
    warn "Hook '$hook_file' is not owned by current user - skipping for security"
    return 1
  fi

  # Check for world-writable (macOS: last digit of octal perms)
  local file_perms; file_perms="$(stat -f %Lp "$hook_file" 2>/dev/null)"
  if [[ "${file_perms: -1}" =~ [2367] ]]; then
    warn "Hook '$hook_file' is world-writable - skipping for security"
    return 1
  fi

  return 0
}

# Run hooks for a given event
# Usage: run_hooks <hook_name> <repo> <branch> <wt_path> <app_url> <db_name>
# Example: run_hooks "post-add" "$repo" "$branch" "$wt_path" "$app_url" "$db_name"
run_hooks() {
  local hook_name="$1"
  local repo="$2"
  local branch="$3"
  local wt_path="$4"
  local app_url="$5"
  local db_name="$6"

  # Check if hooks directory exists
  [[ -d "$WT_HOOKS_DIR" ]] || return 0

  local hook_file="$WT_HOOKS_DIR/$hook_name"

  # Check if hook exists and is executable
  if [[ -x "$hook_file" ]]; then
    # Security check before executing
    if ! verify_hook_security "$hook_file"; then
      return 0
    fi

    info "Running ${C_CYAN}$hook_name${C_RESET} hook..."

    # Export environment variables for the hook
    (
      export WT_REPO="$repo"
      export WT_BRANCH="$branch"
      export WT_PATH="$wt_path"
      export WT_URL="$app_url"
      export WT_DB_NAME="$db_name"
      export WT_HOOK_NAME="$hook_name"
      # Control flags for hooks
      [[ "$NO_BACKUP" == true ]] && export WT_NO_BACKUP="true"
      [[ "$DROP_DB" == true ]] && export WT_DROP_DB="true"

      # Run hook from the worktree directory
      cd "$wt_path" 2>/dev/null || cd "$HOME"

      if "$hook_file"; then
        ok "Hook ${C_CYAN}$hook_name${C_RESET} completed"
      else
        warn "Hook ${C_CYAN}$hook_name${C_RESET} exited with non-zero status"
      fi
    )
  elif [[ -f "$hook_file" ]]; then
    dim "  Hook $hook_name exists but is not executable. Run: chmod +x $hook_file"
  fi

  # Also check for numbered hooks (post-add.d/*.sh pattern for multiple hooks)
  local hooks_d="$WT_HOOKS_DIR/${hook_name}.d"
  if [[ -d "$hooks_d" ]]; then
    # Run global hooks (files only, not directories)
    for hook_script in "$hooks_d"/*(N.x); do
      # Security check before executing
      if ! verify_hook_security "$hook_script"; then
        continue
      fi

      local script_name="${hook_script:t}"
      info "Running ${C_CYAN}$hook_name.d/$script_name${C_RESET}..."

      (
        export WT_REPO="$repo"
        export WT_BRANCH="$branch"
        export WT_PATH="$wt_path"
        export WT_URL="$app_url"
        export WT_DB_NAME="$db_name"
        export WT_HOOK_NAME="$hook_name"
        [[ "$NO_BACKUP" == true ]] && export WT_NO_BACKUP="true"
        [[ "$DROP_DB" == true ]] && export WT_DROP_DB="true"

        cd "$wt_path" 2>/dev/null || cd "$HOME"

        if "$hook_script"; then
          ok "  $script_name completed"
        else
          warn "  $script_name exited with non-zero status"
        fi
      )
    done

    # Run repo-specific hooks (from subdirectory matching repo name)
    local repo_hooks_d="$hooks_d/$repo"
    if [[ -d "$repo_hooks_d" ]]; then
      for hook_script in "$repo_hooks_d"/*(N.x); do
        # Security check before executing
        if ! verify_hook_security "$hook_script"; then
          continue
        fi

        local script_name="${hook_script:t}"
        info "Running ${C_CYAN}$hook_name.d/$repo/$script_name${C_RESET}..."

        (
          export WT_REPO="$repo"
          export WT_BRANCH="$branch"
          export WT_PATH="$wt_path"
          export WT_URL="$app_url"
          export WT_DB_NAME="$db_name"
          export WT_HOOK_NAME="$hook_name"
          [[ "$NO_BACKUP" == true ]] && export WT_NO_BACKUP="true"
          [[ "$DROP_DB" == true ]] && export WT_DROP_DB="true"

          cd "$wt_path" 2>/dev/null || cd "$HOME"

          if "$hook_script"; then
            ok "  $repo/$script_name completed"
          else
            warn "  $repo/$script_name exited with non-zero status"
          fi
        )
      done
    fi
  fi

  return 0
}
