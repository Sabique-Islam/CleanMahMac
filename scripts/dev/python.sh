#!/usr/bin/env bash
# shellcheck shell=bash
# Python: pip, uv, and poetry caches.

cmm_python_cache_paths() {
  printf '%s\n' \
    "${HOME}/Library/Caches/pip" \
    "${HOME}/.cache/pip" \
    "${HOME}/.cache/uv" \
    "${HOME}/Library/Caches/pypoetry"
}

cmm_scan_python() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "python" "Python cache" "$path"
  done < <(cmm_python_cache_paths)
}

cmm_clean_python() {
  cmm_reset_scan
  cmm_scan_python
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Python"
    return 0
  fi

  cmm_log_section "Python cache cleanup"
  cmm_print_scan_results

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Total reclaimable: $(cmm_format_bytes "$total")"
    return 0
  fi

  cmm_confirm_destructive "$total" "$count" || return 1

  if cmm_tool_exists pip3; then
    pip3 cache purge 2>/dev/null || true
  fi
  if cmm_tool_exists uv; then
    uv cache clean 2>/dev/null || true
  fi
  if cmm_tool_exists poetry; then
    poetry cache clear --all pypi 2>/dev/null || true
  fi

  local entry path
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path _ _ <<< "$entry"
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Python cache cleanup complete"
}
