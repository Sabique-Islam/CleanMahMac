#!/usr/bin/env bash
# shellcheck shell=bash
# Xcode caches: DerivedData, Archives, DeviceSupport, CoreSimulator, SwiftPM.

cmm_xcode_paths() {
  printf '%s\n' \
    "${HOME}/Library/Developer/Xcode/DerivedData" \
    "${HOME}/Library/Developer/Xcode/Archives" \
    "${HOME}/Library/Developer/Xcode/iOS DeviceSupport" \
    "${HOME}/Library/Developer/CoreSimulator" \
    "${HOME}/Library/Caches/org.swift.swiftpm"
}

cmm_scan_xcode() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "xcode" "Xcode cache" "$path"
  done < <(cmm_xcode_paths)
}

cmm_clean_xcode() {
  cmm_reset_scan
  cmm_scan_xcode
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Xcode"
    return 0
  fi

  cmm_log_section "Xcode cleanup"
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
  cmm_log_ok "Xcode cleanup complete — reclaimed $(cmm_format_bytes "$total")"
}
