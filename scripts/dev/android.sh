#!/usr/bin/env bash
# shellcheck shell=bash
# Android Studio caches, emulator AVDs, Gradle caches, old SDK images.

cmm_android_paths() {
  printf '%s\n' \
    "${HOME}/.android/cache" \
    "${HOME}/.android/avd" \
    "${HOME}/.gradle/caches" \
    "${HOME}/Library/Android/sdk/.temp" \
    "${HOME}/Library/Caches/Google/AndroidStudio" \
    "${HOME}/Library/Application Support/Google/AndroidStudio2024.1"
}

cmm_scan_android() {
  local path
  while IFS= read -r path; do
    [[ -e "$path" ]] || continue
    cmm_add_scan_result "android" "Android cache" "$path"
  done < <(cmm_android_paths)

  local sdk="${HOME}/Library/Android/sdk/system-images"
  if [[ -d "$sdk" ]]; then
    cmm_add_scan_result "android" "Android SDK system images" "$sdk"
  fi
}

cmm_clean_android() {
  cmm_reset_scan
  cmm_scan_android
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  if (( count == 0 )); then
    cmm_log_ok "Nothing to clean for Android"
    return 0
  fi

  cmm_log_section "Android cleanup"
  cmm_print_scan_results

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Total reclaimable: $(cmm_format_bytes "$total")"
    cmm_log_warn "AVD removal is destructive — review carefully before --force"
    return 0
  fi

  cmm_confirm_destructive "$total" "$count" || return 1

  local entry path label
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ label path _ _ <<< "$entry"
    if [[ "$label" == *"AVD"* ]] || [[ "$path" == *"/avd" ]]; then
      cmm_confirm "Remove AVD data at $path?" 1 || continue
    fi
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Android cleanup complete"
}
