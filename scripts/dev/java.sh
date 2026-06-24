#!/usr/bin/env bash
# shellcheck shell=bash
# Java: Gradle and Maven caches.

cmm_java_cache_paths() {
  printf '%s\n' \
    "${HOME}/.gradle/caches" \
    "${HOME}/.m2/repository"
}

cmm_scan_java() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "java" "Java build cache" "$path"
  done < <(cmm_java_cache_paths)
}

cmm_clean_java() {
  cmm_reset_scan
  cmm_scan_java
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Java"
    return 0
  fi

  cmm_log_section "Java cache cleanup"
  cmm_print_scan_results

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Total reclaimable: $(cmm_format_bytes "$total")"
    return 0
  fi

  cmm_confirm_destructive "$total" "$count" || return 1

  local entry path
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path _ _ <<< "$entry"
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Java cache cleanup complete"
}
