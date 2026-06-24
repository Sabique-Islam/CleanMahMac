#!/usr/bin/env bash
# shellcheck shell=bash
# Node: npm, pnpm, and yarn caches.

cmm_node_cache_paths() {
  printf '%s\n' \
    "${HOME}/.npm" \
    "${HOME}/.pnpm-store" \
    "${HOME}/Library/Caches/Yarn"
}

cmm_scan_node() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "node" "Node package cache" "$path"
  done < <(cmm_node_cache_paths)
}

cmm_clean_node() {
  cmm_reset_scan
  cmm_scan_node
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Node"
    return 0
  fi

  cmm_log_section "Node cache cleanup"
  cmm_print_scan_results

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Total reclaimable: $(cmm_format_bytes "$total")"
    if cmm_tool_exists npm; then
      cmm_log_dry "Would also run: npm cache clean --force"
    fi
    return 0
  fi

  cmm_confirm_destructive "$total" "$count" || return 1

  if cmm_tool_exists npm; then
    npm cache clean --force 2>/dev/null || cmm_log_warn "npm cache clean failed"
  fi

  local entry path
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path _ _ <<< "$entry"
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Node cache cleanup complete"
}
