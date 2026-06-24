#!/usr/bin/env bash
# shellcheck shell=bash
# Bootstrap shared utilities for all CleanMahMac scripts.

set -euo pipefail

: "${CMM_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
: "${CMM_DRY_RUN:=1}"
: "${CMM_FORCE:=0}"
: "${CMM_YES:=0}"
: "${CMM_JSON:=0}"

# shellcheck source=scripts/utils/colors.sh
source "${CMM_ROOT}/scripts/utils/colors.sh"
# shellcheck source=scripts/utils/logger.sh
source "${CMM_ROOT}/scripts/utils/logger.sh"
# shellcheck source=scripts/utils/size.sh
source "${CMM_ROOT}/scripts/utils/size.sh"
# shellcheck source=scripts/utils/validation.sh
source "${CMM_ROOT}/scripts/utils/validation.sh"
# shellcheck source=scripts/utils/confirm.sh
source "${CMM_ROOT}/scripts/utils/confirm.sh"
# shellcheck source=scripts/utils/tui.sh
source "${CMM_ROOT}/scripts/utils/tui.sh"
# shellcheck source=scripts/utils/permissions.sh
source "${CMM_ROOT}/scripts/utils/permissions.sh"
# shellcheck source=scripts/utils/user-config.sh
source "${CMM_ROOT}/scripts/utils/user-config.sh"

CMM_SCAN_RESULTS=()
CMM_SCAN_TOTAL_BYTES=0

cmm_add_scan_result() {
  local module="$1"
  local label="$2"
  local path="$3"
  local bytes="${4:-0}"
  local meta="${5:-}"

  if [[ "$bytes" == "0" ]] && [[ -e "$path" ]]; then
    bytes="$(cmm_size_bytes "$path")"
  fi

  if (( bytes <= 0 )); then
    return 0
  fi

  CMM_SCAN_RESULTS+=("${module}|${label}|${path}|${bytes}|${meta}")
  CMM_SCAN_TOTAL_BYTES=$((CMM_SCAN_TOTAL_BYTES + bytes))
}

cmm_reset_scan() {
  CMM_SCAN_RESULTS=()
  CMM_SCAN_TOTAL_BYTES=0
}

cmm_tool_exists() {
  command -v "$1" >/dev/null 2>&1
}

cmm_read_json_default() {
  local key="$1"
  local default="$2"
  python3 -c "
import json, os, sys
root = os.environ.get('CMM_ROOT', '.')
with open(os.path.join(root, 'configs/rules.json')) as f:
    data = json.load(f)
keys = sys.argv[1].split('.')
val = data.get('defaults', {})
for k in keys:
    if isinstance(val, dict) and k in val:
        val = val[k]
    else:
        print(sys.argv[2])
        sys.exit(0)
if isinstance(val, list):
    print('\n'.join(val))
else:
    print(val)
" "$key" "$default" 2>/dev/null || printf '%s' "$default"
}

cmm_load_modules() {
  CMM_MODULES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && CMM_MODULES+=("$line")
  done < <(python3 -c "
import json, os
with open(os.path.join('${CMM_ROOT}', 'configs/rules.json')) as f:
    for m in json.load(f)['modules']:
        print(m)
")
}

cmm_module_script() {
  local module="$1"
  printf '%s/scripts/dev/%s.sh' "$CMM_ROOT" "$module"
}

cmm_run_module_scan() {
  local module="$1"
  local script
  script="$(cmm_module_script "$module")"
  if [[ ! -f "$script" ]]; then
    cmm_log_warn "Module not found: $module"
    return 0
  fi
  # shellcheck source=/dev/null
  source "$script"
  local fn="cmm_scan_${module//-/_}"
  if declare -f "$fn" >/dev/null 2>&1; then
    "$fn"
  else
    cmm_log_warn "Scan function missing: $fn"
  fi
}

cmm_run_module_clean() {
  local module="$1"
  local script
  script="$(cmm_module_script "$module")"
  if [[ ! -f "$script" ]]; then
    cmm_log_error "Module not found: $module"
    return 1
  fi
  # shellcheck source=/dev/null
  source "$script"
  local fn="cmm_clean_${module//-/_}"
  if declare -f "$fn" >/dev/null 2>&1; then
    "$fn"
  else
    cmm_log_error "Clean function missing: $fn"
    return 1
  fi
}

cmm_print_scan_results() {
  local entry module label path bytes meta
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r module label path bytes meta <<< "$entry"
    if [[ -n "$meta" ]]; then
      printf '  %s\n    %s\n    %s: %s\n' "$path" "$meta" "$label" "$(cmm_format_bytes "$bytes")"
    else
      printf '  %s — %s (%s)\n' "$label" "$path" "$(cmm_format_bytes "$bytes")"
    fi
  done
}
