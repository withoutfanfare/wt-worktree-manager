#!/usr/bin/env zsh
# 08-spinner.sh - Progress indicators for long operations

# Spinner characters (Braille pattern for smooth animation)
readonly SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
readonly SPINNER_DELAY=0.08

# Spinner state
typeset -g SPINNER_PID=""
typeset -g SPINNER_MSG=""

# Start a spinner in the background
# Usage: spinner_start "Installing dependencies..."
spinner_start() {
  local msg="$1"
  SPINNER_MSG="$msg"

  # Don't show spinner if not a TTY or in quiet mode
  [[ -t 1 && "$QUIET" != true ]] || return 0

  # Kill any existing spinner
  spinner_stop 2>/dev/null || true

  (
    local i=0
    local chars_len=${#SPINNER_CHARS}
    while true; do
      local char="${SPINNER_CHARS:$i:1}"
      printf "\r${C_CYAN}%s${C_RESET} %s" "$char" "$msg" >&2
      i=$(( (i + 1) % chars_len ))
      sleep "$SPINNER_DELAY"
    done
  ) &
  SPINNER_PID=$!
  disown $SPINNER_PID 2>/dev/null || true
}

# Stop spinner and show result
# Usage: spinner_stop "ok" or spinner_stop "fail" or spinner_stop "skip"
spinner_stop() {
  local result="${1:-ok}"

  # Kill spinner process
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
  fi

  [[ -t 1 && "$QUIET" != true ]] || return 0

  # Clear spinner line
  printf "\r\033[K" >&2

  # Show result
  case "$result" in
    ok)   print -r -- "${C_GREEN}✔${C_RESET} $SPINNER_MSG" ;;
    fail) print -r -- "${C_RED}✖${C_RESET} $SPINNER_MSG" ;;
    skip) print -r -- "${C_DIM}○${C_RESET} $SPINNER_MSG ${C_DIM}(skipped)${C_RESET}" ;;
  esac

  SPINNER_MSG=""
}

# Run a command with spinner
# Usage: with_spinner "Installing npm packages" npm install
# Returns the exit code of the command
with_spinner() {
  local msg="$1"
  shift

  spinner_start "$msg"

  local exit_code=0
  if "$@" >/dev/null 2>&1; then
    spinner_stop "ok"
  else
    exit_code=$?
    spinner_stop "fail"
  fi

  return $exit_code
}

# Step progress indicator for multi-step operations
# Usage: step_progress 1 5 "Installing dependencies"
step_progress() {
  local current="$1" total="$2" msg="$3"
  [[ -t 1 && "$QUIET" != true ]] || return 0
  printf "\r${C_DIM}[%d/%d]${C_RESET} %s" "$current" "$total" "$msg" >&2
}

# Clear step progress line
step_complete() {
  [[ -t 1 && "$QUIET" != true ]] || return 0
  printf "\r\033[K" >&2
}

# Ensure spinner is stopped on script exit
trap 'spinner_stop 2>/dev/null' EXIT INT TERM
