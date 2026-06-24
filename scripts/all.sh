#!/usr/bin/env bash
# shellcheck shell=bash
# Orchestrate cleanup across all modules.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"

cmm_all_main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        CMM_DRY_RUN=0
        CMM_FORCE=1
        export CMM_DRY_RUN CMM_FORCE
        shift
        ;;
      --yes)
        CMM_YES=1
        export CMM_YES
        shift
        ;;
      --volumes)
        CMM_DOCKER_VOLUMES=1
        export CMM_DOCKER_VOLUMES
        shift
        ;;
      *)
        shift
        ;;
    esac
  done

  cmm_load_modules
  local modules=("${CMM_MODULES[@]}")

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_section "Dry-run: all modules"
    cmm_log_info "Pass --force to delete (e.g. cmm clean all --force)"
    cmm_reset_scan
    local module
    for module in "${modules[@]}"; do
      cmm_run_module_scan "$module"
    done
    cmm_print_scan_results
    printf '\n%s %s\n' "$(cmm_color_bold "Total reclaimable:")" "$(cmm_format_bytes "$CMM_SCAN_TOTAL_BYTES")"
    return 0
  fi

  cmm_log_section "Cleaning all modules"
  cmm_confirm "Run all cleanup modules? This may take a while." 1 || return 1

  local module failed=0
  for module in "${modules[@]}"; do
    cmm_log_info "Module: $module"
    cmm_run_module_clean "$module" || failed=1
  done

  if (( failed == 0 )); then
    cmm_log_ok "All modules complete"
  else
    cmm_log_warn "Some modules failed or were skipped"
    return 1
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_all_main "$@"
fi
