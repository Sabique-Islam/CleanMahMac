#!/usr/bin/env bash
# shellcheck shell=bash
# Flutter: pub cache and build artifacts in common project roots.

cmm_scan_flutter() {
  local pub="${HOME}/.pub-cache"
  [[ -d "$pub" ]] && cmm_add_scan_result "flutter" "Flutter pub cache" "$pub"

  local root marker
  for root in "$HOME/Projects" "$HOME/Code" "$HOME/Workspace" "$HOME/Developer"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r marker; do
      [[ -n "$marker" ]] || continue
      local project="${marker%/pubspec.yaml}"
      local build="${project}/build"
      [[ -d "$build" ]] && cmm_add_scan_result "flutter" "Flutter build" "$build"
    done < <(find "$root" -maxdepth 4 -name pubspec.yaml 2>/dev/null || true)
  done
}

cmm_clean_flutter() {
  cmm_reset_scan
  cmm_scan_flutter
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Flutter"
    return 0
  fi

  cmm_log_section "Flutter cleanup"
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
  cmm_log_ok "Flutter cleanup complete"
}
