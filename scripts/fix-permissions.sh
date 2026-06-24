#!/usr/bin/env bash
# shellcheck shell=bash
# Fix executable permissions for all CleanMahMac scripts.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"

cmm_fix_permissions_main() {
  cmm_log_section "Fixing script permissions"
  if cmm_chmod_repo_scripts "${CMM_ROOT}"; then
    cmm_log_ok "All scripts are now executable."
    local missing
    missing="$(cmm_find_non_executable_scripts "${CMM_ROOT}" | wc -l | tr -d ' ')"
    if (( missing > 0 )); then
      cmm_log_warn "$missing script(s) still not executable — repo may be read-only."
      cmm_print_chmod_instructions "${CMM_ROOT}"
      return 1
    fi
    return 0
  fi
  cmm_print_chmod_instructions "${CMM_ROOT}"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_fix_permissions_main "$@"
fi
