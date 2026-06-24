#!/usr/bin/env bash
# shellcheck shell=bash
# Interactive user configuration.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"
# shellcheck source=scripts/utils/user-config.sh
source "${CMM_ROOT}/scripts/utils/user-config.sh"

cmm_configure_main() {
  local section="${1:-}"

  case "$section" in
    ''|scan-roots|roots)
      cmm_configure_scan_roots_interactive
      ;;
    show)
      cmm_load_saved_scan_roots
      if ((${#CMM_USER_SCAN_ROOTS[@]} == 0)); then
        cmm_log_warn "No scan folders configured. Run 'cmm configure'."
        return 0
      fi
      cmm_log_info "Configured scan folders:"
      local root
      for root in "${CMM_USER_SCAN_ROOTS[@]}"; do
        printf '  • %s\n' "$root"
      done
      ;;
    *)
      cmm_log_error "Unknown configure section: $section"
      printf 'Usage: cmm configure [scan-roots|show]\n' >&2
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_configure_main "$@"
fi
