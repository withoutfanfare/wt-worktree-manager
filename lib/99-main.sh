#!/usr/bin/env zsh
# 99-main.sh - Main entry point, usage, and flag parsing

usage() {
  print -r -- ""
  print -r -- "${C_BOLD}wt${C_RESET} v$VERSION - Git worktree manager for Laravel Herd"
  print -r -- ""
  print -r -- "${C_BOLD}USAGE${C_RESET}"
  print -r -- "  wt [flags] <command> [args]"
  print -r -- ""
  print -r -- "${C_BOLD}CORE COMMANDS${C_RESET}"
  print -r -- "  ${C_GREEN}add${C_RESET}      ${C_DIM}<repo> <branch> [base]${C_RESET}     Create worktree"
  print -r -- "           ${C_DIM}--template=<name>, -t <name>${C_RESET}  Use template"
  print -r -- "           ${C_DIM}--dry-run${C_RESET}                     Preview without creating"
  print -r -- "           ${C_DIM}--interactive, -i${C_RESET}             Guided creation wizard"
  print -r -- "  ${C_GREEN}rm${C_RESET}       ${C_DIM}<repo> [branch]${C_RESET}            Remove worktree"
  print -r -- "  ${C_GREEN}ls${C_RESET}       ${C_DIM}<repo>${C_RESET}                     List worktrees"
  print -r -- "  ${C_GREEN}repos${C_RESET}                               List all repositories"
  print -r -- "  ${C_GREEN}clone${C_RESET}    ${C_DIM}<url> [name] [branch]${C_RESET}      Clone as bare repo"
  print -r -- ""
  print -r -- "${C_BOLD}GIT COMMANDS${C_RESET} ${C_DIM}(auto-detect repo/branch when run from worktree)${C_RESET}"
  print -r -- "  ${C_GREEN}status${C_RESET}   ${C_DIM}<repo>${C_RESET}                     Dashboard view of all worktrees"
  print -r -- "  ${C_GREEN}pull${C_RESET}     ${C_DIM}[repo] [branch]${C_RESET}            Pull latest changes"
  print -r -- "  ${C_GREEN}pull-all${C_RESET} ${C_DIM}<repo>${C_RESET}                     Pull all worktrees (parallel)"
  print -r -- "  ${C_GREEN}sync${C_RESET}     ${C_DIM}[repo] [branch] [base]${C_RESET}     Rebase onto base branch"
  print -r -- "  ${C_GREEN}diff${C_RESET}     ${C_DIM}[repo] [branch] [base]${C_RESET}     Show diff against base branch"
  print -r -- "  ${C_GREEN}log${C_RESET}      ${C_DIM}[repo] [branch]${C_RESET}            Show recent commits"
  print -r -- "  ${C_GREEN}prune${C_RESET}    ${C_DIM}<repo>${C_RESET}                     Clean up stale worktrees"
  print -r -- ""
  print -r -- "${C_BOLD}PARALLEL COMMANDS${C_RESET}"
  print -r -- "  ${C_GREEN}build-all${C_RESET} ${C_DIM}<repo>${C_RESET}                    npm run build on all"
  print -r -- "  ${C_GREEN}exec-all${C_RESET}  ${C_DIM}<repo> <cmd>${C_RESET}              Run command on all"
  print -r -- ""
  print -r -- "${C_BOLD}LARAVEL COMMANDS${C_RESET} ${C_DIM}(auto-detect when run from worktree)${C_RESET}"
  print -r -- "  ${C_GREEN}fresh${C_RESET}    ${C_DIM}[repo] [branch]${C_RESET}            migrate:fresh + npm ci + build"
  print -r -- "  ${C_GREEN}migrate${C_RESET}  ${C_DIM}[repo] [branch]${C_RESET}            Run artisan migrate"
  print -r -- "  ${C_GREEN}tinker${C_RESET}   ${C_DIM}[repo] [branch]${C_RESET}            Run artisan tinker"
  print -r -- ""
  print -r -- "${C_BOLD}NAVIGATION${C_RESET} ${C_DIM}(auto-detect when run from worktree)${C_RESET}"
  print -r -- "  ${C_GREEN}code${C_RESET}     ${C_DIM}[repo] [branch]${C_RESET}            Open in editor"
  print -r -- "  ${C_GREEN}open${C_RESET}     ${C_DIM}[repo] [branch]${C_RESET}            Open URL in browser"
  print -r -- "  ${C_GREEN}cd${C_RESET}       ${C_DIM}[repo] [branch]${C_RESET}            Print worktree path"
  print -r -- "  ${C_GREEN}switch${C_RESET}   ${C_DIM}<repo> [branch]${C_RESET}            cd + code + open in one"
  print -r -- "  ${C_GREEN}exec${C_RESET}     ${C_DIM}<repo> <branch> <cmd>${C_RESET}      Run command in worktree"
  print -r -- ""
  print -r -- "${C_BOLD}UTILITIES${C_RESET}"
  print -r -- "  ${C_GREEN}doctor${C_RESET}                              Check system requirements"
  print -r -- "  ${C_GREEN}health${C_RESET}   ${C_DIM}<repo>${C_RESET}                     Check repository health"
  print -r -- "  ${C_GREEN}repair${C_RESET}   ${C_DIM}[repo]${C_RESET}                     Fix common issues"
  print -r -- "  ${C_GREEN}report${C_RESET}   ${C_DIM}<repo> [--output <file>]${C_RESET}  Generate markdown status report"
  print -r -- "  ${C_GREEN}cleanup-herd${C_RESET}                        Remove orphaned Herd nginx configs"
  print -r -- "  ${C_GREEN}unlock${C_RESET}   ${C_DIM}[repo]${C_RESET}                    Remove stale git lock files"
  print -r -- ""
  print -r -- "${C_BOLD}FLAGS${C_RESET}"
  print -r -- "  ${C_YELLOW}-q, --quiet${C_RESET}          Suppress informational output"
  print -r -- "  ${C_YELLOW}-f, --force${C_RESET}          Skip confirmations / force protected branch removal"
  print -r -- "  ${C_YELLOW}-i, --interactive${C_RESET}    Launch interactive worktree creation wizard"
  print -r -- "  ${C_YELLOW}--json${C_RESET}               Output in JSON format"
  print -r -- "  ${C_YELLOW}--pretty${C_RESET}             Pretty-print JSON output with colours"
  print -r -- "  ${C_YELLOW}--dry-run${C_RESET}            Preview actions without executing (wt add)"
  print -r -- "  ${C_YELLOW}-t, --template${C_RESET}       Apply template when creating worktree"
  print -r -- "  ${C_YELLOW}--delete-branch${C_RESET}      Delete branch when removing worktree"
  print -r -- "  ${C_YELLOW}--drop-db${C_RESET}            Drop database when removing worktree"
  print -r -- "  ${C_YELLOW}--no-backup${C_RESET}          Skip database backup when removing worktree"
  print -r -- "  ${C_YELLOW}-v, --version${C_RESET}        Show version"
  print -r -- ""
  print -r -- "${C_BOLD}EXAMPLES${C_RESET}"
  print -r -- "  ${C_DIM}# Set up a new project${C_RESET}"
  print -r -- "  wt clone git@github.com:org/myapp.git"
  print -r -- "  wt add myapp feature/login"
  print -r -- ""
  print -r -- "  ${C_DIM}# Interactive worktree creation${C_RESET}"
  print -r -- "  wt add --interactive"
  print -r -- ""
  print -r -- "  ${C_DIM}# Navigate to worktree${C_RESET}"
  print -r -- "  cd \"\$(wt cd myapp feature/login)\""
  print -r -- ""
  print -r -- "  ${C_DIM}# Interactive selection (requires fzf)${C_RESET}"
  print -r -- "  wt code myapp              ${C_DIM}# opens fzf picker${C_RESET}"
  print -r -- ""
  print -r -- "  ${C_DIM}# Run command in worktree${C_RESET}"
  print -r -- "  wt exec myapp feature/login php artisan migrate"
  print -r -- ""
  print -r -- "  ${C_DIM}# Parallel operations${C_RESET}"
  print -r -- "  wt pull-all myapp          ${C_DIM}# pull all worktrees${C_RESET}"
  print -r -- "  wt build-all myapp         ${C_DIM}# build all worktrees${C_RESET}"
  print -r -- ""
  print -r -- "  ${C_DIM}# Use template with dry-run preview${C_RESET}"
  print -r -- "  wt add myapp feature/api --template=backend --dry-run"
  print -r -- ""
  print -r -- "${C_BOLD}AVAILABLE TEMPLATES${C_RESET}"
  list_templates
  print -r -- ""
  print -r -- "  ${C_DIM}Run 'wt templates' for details or 'wt templates <name>' to view a template${C_RESET}"
  print -r -- ""
  print -r -- "${C_BOLD}ENVIRONMENT${C_RESET}"
  print -r -- "  ${C_YELLOW}HERD_ROOT${C_RESET}         Herd directory ${C_DIM}(default: \$HOME/Herd)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_BASE_DEFAULT${C_RESET}   Default base branch ${C_DIM}(default: origin/staging)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_EDITOR${C_RESET}         Editor command ${C_DIM}(default: cursor)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_CONFIG${C_RESET}         Config file path ${C_DIM}(default: ~/.wtrc)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_URL_SUBDOMAIN${C_RESET}  Optional URL subdomain ${C_DIM}(e.g., api -> api.feature.test)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_HOOKS_DIR${C_RESET}      Hooks directory ${C_DIM}(default: ~/.wt/hooks)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_MAX_PARALLEL${C_RESET}   Max parallel operations ${C_DIM}(default: 4)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_DB_HOST${C_RESET}        MySQL host ${C_DIM}(default: 127.0.0.1)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_DB_USER${C_RESET}        MySQL user ${C_DIM}(default: root)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_DB_PASSWORD${C_RESET}    MySQL password ${C_DIM}(default: empty)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_DB_CREATE${C_RESET}      Auto-create database ${C_DIM}(default: true)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_DB_BACKUP${C_RESET}      Backup database on remove ${C_DIM}(default: true)${C_RESET}"
  print -r -- "  ${C_YELLOW}WT_DB_BACKUP_DIR${C_RESET}  Backup directory ${C_DIM}(default: ~/Code/Project Support/...)${C_RESET}"
  print -r -- ""
  print -r -- "${C_BOLD}CONFIG FILE${C_RESET}"
  print -r -- "  Create ${C_CYAN}~/.wtrc${C_RESET} or ${C_CYAN}\$HERD_ROOT/.wtconfig${C_RESET} with:"
  print -r -- "    HERD_ROOT=/path/to/herd"
  print -r -- "    DEFAULT_BASE=origin/main"
  print -r -- "    DEFAULT_EDITOR=code"
  print -r -- "    WT_URL_SUBDOMAIN=api       ${C_DIM}# optional: api.feature.test${C_RESET}"
  print -r -- "    DB_USER=root"
  print -r -- "    DB_PASSWORD=secret"
  print -r -- "    DB_BACKUP_DIR=/path/to/backups"
  print -r -- ""
  print -r -- "${C_BOLD}HOOKS${C_RESET}"
  print -r -- "  Create executable scripts in ${C_CYAN}~/.wt/hooks/${C_RESET} to run custom commands:"
  print -r -- ""
  print -r -- "  ${C_GREEN}pre-add${C_RESET}      Run before worktree creation (can abort)"
  print -r -- "  ${C_GREEN}post-add${C_RESET}     Run after worktree creation"
  print -r -- "  ${C_GREEN}pre-rm${C_RESET}       Run before worktree removal (can abort)"
  print -r -- "  ${C_GREEN}post-rm${C_RESET}      Run after worktree removal"
  print -r -- "  ${C_GREEN}post-pull${C_RESET}    Run after wt pull succeeds"
  print -r -- "  ${C_GREEN}post-sync${C_RESET}    Run after wt sync succeeds"
  print -r -- ""
  print -r -- "  ${C_DIM}Available environment variables in hooks:${C_RESET}"
  print -r -- "    WT_REPO       Repository name"
  print -r -- "    WT_BRANCH     Branch name"
  print -r -- "    WT_PATH       Worktree path"
  print -r -- "    WT_URL        Application URL"
  print -r -- "    WT_DB_NAME    Database name"
  print -r -- ""
  print -r -- "  ${C_DIM}Example ~/.wt/hooks/post-add:${C_RESET}"
  print -r -- "    #!/bin/bash"
  print -r -- "    npm ci && npm run build"
  print -r -- "    php artisan migrate"
  print -r -- ""
  print -r -- "  ${C_DIM}Multiple hooks: Create ~/.wt/hooks/post-add.d/ with numbered scripts${C_RESET}"
  print -r -- "  ${C_DIM}Repo-specific: Create ~/.wt/hooks/post-add.d/<repo>/ for repo-only hooks${C_RESET}"
  print -r -- ""
}

# Parse global flags (can appear anywhere in command line)
parse_flags() {
  REMAINING_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -q|--quiet) QUIET=true ;;
      -f|--force) FORCE=true ;;
      -i|--interactive) INTERACTIVE=true ;;
      --json) JSON_OUTPUT=true ;;
      --delete-branch) DELETE_BRANCH=true ;;
      --drop-db) DROP_DB=true ;;
      --no-backup) NO_BACKUP=true ;;
      --dry-run) DRY_RUN=true ;;
      --pretty) PRETTY_JSON=true ;;
      --template=*)
        WT_TEMPLATE="${1#--template=}"
        if [[ -z "$WT_TEMPLATE" ]]; then
          setup_colors
          die "Template name cannot be empty"
        fi
        ;;
      -t)
        shift
        if [[ -z "${1:-}" || "$1" == -* ]]; then
          setup_colors
          die "Template name required after -t flag"
        fi
        WT_TEMPLATE="$1"
        ;;
      -v|--version) print -r -- "wt version $VERSION"; exit 0 ;;
      -h|--help|help) setup_colors; usage; exit 0 ;;
      -*) setup_colors; die "Unknown flag: $1" ;;
      *) REMAINING_ARGS+=("$1") ;;
    esac
    shift
  done
}

main() {
  load_config
  parse_flags "$@"
  setup_colors

  set -- "${REMAINING_ARGS[@]}"

  local cmd="${1:-}"
  shift || true

  # Handle interactive mode for add command
  if [[ "$INTERACTIVE" == true ]]; then
    if [[ -z "$cmd" || "$cmd" == "add" ]]; then
      interactive_add "$@"
      return $?
    fi
  fi

  case "$cmd" in
    add)          cmd_add "$@" ;;
    rm)           cmd_rm "$@" ;;
    ls)           cmd_ls "$@" ;;
    status)       cmd_status "$@" ;;
    pull)         cmd_pull "$@" ;;
    pull-all)     cmd_pull_all "$@" ;;
    sync)         cmd_sync "$@" ;;
    clone)        cmd_clone "$@" ;;
    code)         cmd_code "$@" ;;
    open)         cmd_open "$@" ;;
    cd)           cmd_cd "$@" ;;
    exec)         cmd_exec "$@" ;;
    prune)        cmd_prune "$@" ;;
    repos)        cmd_repos "$@" ;;
    templates)    cmd_templates "$@" ;;
    doctor)       cmd_doctor "$@" ;;
    cleanup-herd) cmd_cleanup_herd "$@" ;;
    unlock)       cmd_unlock "$@" ;;
    fresh)        cmd_fresh "$@" ;;
    build-all)    cmd_build_all "$@" ;;
    exec-all)     cmd_exec_all "$@" ;;
    repair)       cmd_repair "$@" ;;
    switch)       cmd_switch "$@" ;;
    migrate)      cmd_migrate "$@" ;;
    tinker)       cmd_tinker "$@" ;;
    log)          cmd_log "$@" ;;
    diff)         cmd_diff "$@" ;;
    report)       cmd_report "$@" ;;
    health)       cmd_health "$@" ;;
    "")           usage ;;
    *)            die "Unknown command: $cmd (try: wt --help)" ;;
  esac
}

main "$@"
