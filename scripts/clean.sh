#!/usr/bin/env bash
# shellcheck shell=bash
# Dispatch clean commands to the requested module.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"

cmm_clean_main() {
  local module="${1:-}"
  shift || true

  if [[ -z "$module" ]]; then
    cmm_log_error "Usage: cmm clean <module|all> [--force] [--yes] [--volumes]"
    return 1
  fi

  if [[ "$module" == "all" ]]; then
    exec "${CMM_ROOT}/scripts/all.sh" "$@"
  fi

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_info "Dry-run mode (default). Pass --force to delete."
  fi

  cmm_run_module_clean "$module"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_clean_main "$@"
fi
