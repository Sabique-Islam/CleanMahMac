#!/usr/bin/env bash
# shellcheck shell=bash
# Readable summary report grouped by module.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"

cmm_report_main() {
  local modules=("$@")
  local module

  if ((${#modules[@]} == 0)); then
    cmm_load_modules
    modules=("${CMM_MODULES[@]}")
  fi

  cmm_reset_scan
  for module in "${modules[@]}"; do
    cmm_run_module_scan "$module"
  done

  printf '\n%s\n' "$(cmm_color_bold "CleanMahMac Report")"
  printf '%s\n\n' "$(cmm_color_dim "Transparent disk reclamation for developers")"

  local entry mod label path bytes meta project mod_total
  for module in "${modules[@]}"; do
    mod_total=0
    for entry in "${CMM_SCAN_RESULTS[@]}"; do
      IFS='|' read -r mod _ _ bytes _ <<< "$entry"
      [[ "$mod" == "$module" ]] && mod_total=$((mod_total + bytes))
    done
    if (( mod_total == 0 )); then
      continue
    fi
    printf '%s — %s\n' "$(cmm_color_cyan "$module")" "$(cmm_format_bytes "$mod_total")"
    for entry in "${CMM_SCAN_RESULTS[@]}"; do
      IFS='|' read -r m label path bytes meta <<< "$entry"
      [[ "$m" == "$module" ]] || continue
      if [[ "$module" == "abandoned-node-modules" ]]; then
        project="${meta#*project:}"
        meta="${meta%|project:*}"
        printf '  • %s (%s) — %s\n' "$project" "$(cmm_format_bytes "$bytes")" "$meta"
      else
        printf '  • %s — %s (%s)\n' "$label" "$(cmm_format_bytes "$bytes")" "$path"
      fi
    done
    printf '\n'
  done

  if ((${#CMM_SCAN_RESULTS[@]} == 0)); then
    cmm_log_ok "All clear. Your disk thanks you for nothing."
    return 0
  fi

  printf '%s %s\n' "$(cmm_color_bold "Grand total:")" "$(cmm_format_bytes "$CMM_SCAN_TOTAL_BYTES")"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_report_main "$@"
fi
