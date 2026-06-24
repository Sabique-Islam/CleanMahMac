#!/usr/bin/env bash
# shellcheck shell=bash
# Go: build cache and module cache.

cmm_go_cache_paths() {
  printf '%s\n' \
    "${HOME}/Library/Caches/go-build" \
    "${HOME}/go/pkg/mod"
}

cmm_scan_go() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "go" "Go cache" "$path"
  done < <(cmm_go_cache_paths)
}

cmm_clean_go() {
  cmm_reset_scan
  cmm_scan_go
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Go"
    return 0
  fi

  cmm_log_section "Go cache cleanup"
  cmm_print_scan_results

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Total reclaimable: $(cmm_format_bytes "$total")"
    if cmm_tool_exists go; then
      cmm_log_dry "Would also run: go clean -cache -modcache -testcache"
    fi
    return 0
  fi

  cmm_confirm_destructive "$total" "$count" || return 1

  if cmm_tool_exists go; then
    go clean -cache -modcache -testcache 2>/dev/null || cmm_log_warn "go clean failed"
  fi

  local entry path
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path _ _ <<< "$entry"
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Go cache cleanup complete"
}
