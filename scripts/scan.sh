#!/usr/bin/env bash
# shellcheck shell=bash
# Scan all modules and calculate reclaimable space without deleting.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"

cmm_scan_main() {
  local modules=("$@")
  local module

  if ((${#modules[@]} == 0)); then
    cmm_load_modules
    modules=("${CMM_MODULES[@]}")
  fi

  cmm_reset_scan
  cmm_log_section "Scanning for reclaimable dev junk"

  for module in "${modules[@]}"; do
    cmm_log_info "Scanning: $module"
    cmm_run_module_scan "$module"
  done

  if ((${#CMM_SCAN_RESULTS[@]} == 0)); then
    cmm_log_ok "Nothing reclaimable found. Either you're tidy or you're lying."
    return 0
  fi

  cmm_log_section "Scan results"
  cmm_print_scan_results
  printf '\n%s %s\n' "$(cmm_color_bold "Total reclaimable:")" "$(cmm_format_bytes "$CMM_SCAN_TOTAL_BYTES")"
  cmm_log_info "Dry-run by default. Use 'cmm clean <module> --force' to actually delete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_scan_main "$@"
fi
