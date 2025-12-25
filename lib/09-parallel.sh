#!/usr/bin/env zsh
# 09-parallel.sh - Parallel execution framework

# Report results helper
report_results() {
  local success="$1" failed="$2" total="$3"

  print -r -- ""
  if (( failed == 0 )); then
    ok "All $total operation(s) completed successfully"
  else
    warn "$failed of $total operation(s) failed"
  fi
}

# Run operations in parallel with result collection
# Usage: parallel_run <result_handler> <operations...>
# Each operation is: "label|command"
parallel_run() {
  local result_handler="$1"
  shift
  local operations=("$@")

  local total=${#operations[@]}
  [[ $total -eq 0 ]] && return 0

  # Create temp directory for results
  local tmpdir; tmpdir="$(/usr/bin/mktemp -d)"
  trap "/bin/rm -rf '$tmpdir'" EXIT

  # Job tracking
  local pids=()
  local running=0

  info "Running $total operation(s) in parallel (max $WT_MAX_PARALLEL concurrent)..."

  local i=0
  for op in "${operations[@]}"; do
    i=$((i + 1))
    local label="${op%%|*}"
    local cmd="${op#*|}"

    # Wait if at max parallel
    while (( running >= WT_MAX_PARALLEL )); do
      local new_pids=()
      for pid in "${pids[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
          new_pids+=("$pid")
        else
          wait "$pid" 2>/dev/null || true
          running=$((running - 1))
        fi
      done
      pids=("${new_pids[@]}")
      (( running >= WT_MAX_PARALLEL )) && sleep 0.1
    done

    # Launch job
    (
      if eval "$cmd" >/dev/null 2>&1; then
        echo "ok|$label" > "$tmpdir/$i"
      else
        echo "fail|$label" > "$tmpdir/$i"
      fi
    ) &
    pids+=($!)
    running=$((running + 1))
  done

  # Wait for remaining jobs
  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  # Collect and report results
  local success=0 failed=0
  i=0
  for op in "${operations[@]}"; do
    i=$((i + 1))
    if [[ -f "$tmpdir/$i" ]]; then
      local result; result="$(<"$tmpdir/$i")"
      local status="${result%%|*}"
      local label="${result#*|}"

      if [[ "$status" == "ok" ]]; then
        ok "  $label"
        success=$((success + 1))
      else
        warn "  $label - failed"
        failed=$((failed + 1))
      fi
    fi
  done

  /bin/rm -rf "$tmpdir"
  trap - EXIT

  # Call result handler
  "$result_handler" "$success" "$failed" "$total"

  return $(( failed > 0 ? 1 : 0 ))
}
