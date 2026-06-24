#!/usr/bin/env bash
# shellcheck shell=bash
# Rust: cargo registry and git cache.

cmm_rust_cache_paths() {
  printf '%s\n' \
    "${HOME}/.cargo/registry" \
    "${HOME}/.cargo/git"
}

cmm_scan_rust() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "rust" "Rust cargo cache" "$path"
  done < <(cmm_rust_cache_paths)
}

cmm_clean_rust() {
  cmm_reset_scan
  cmm_scan_rust
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Rust"
    return 0
  fi

  cmm_log_section "Rust cache cleanup"
  cmm_print_scan_results

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Total reclaimable: $(cmm_format_bytes "$total")"
    if cmm_tool_exists cargo; then
      cmm_log_dry "Would also run: cargo cache -a"
    fi
    return 0
  fi

  cmm_confirm_destructive "$total" "$count" || return 1

  if cmm_tool_exists cargo && cargo cache --help >/dev/null 2>&1; then
    cargo cache -a 2>/dev/null || true
  fi

  local entry path
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path _ _ <<< "$entry"
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Rust cache cleanup complete"
}
