#!/usr/bin/env bash
# shellcheck shell=bash
# Executable permission checks and guided self-fix.

cmm_is_executable() {
  [[ -f "$1" && -x "$1" ]]
}

cmm_chmod_repo_scripts() {
  local root="${1:-${CMM_ROOT}}"
  find "$root" -type f \( -name '*.sh' -o -name 'cmm' -o -name 'install.sh' -o -name 'uninstall.sh' \) \
    ! -path '*/tests/fixtures/*' -exec chmod +x {} +
}

cmm_print_chmod_instructions() {
  local root="${1:-${CMM_ROOT}}"
  cmm_log_warn "Some scripts are not executable. Run this from your repo:"
  printf '\n  chmod +x %s/cmm %s/install.sh %s/uninstall.sh\n' "$root" "$root" "$root"
  printf '  find %s -type f \\( -name '"'"'*.sh'"'"' -o -name cmm \\) ! -path '"'"'*/tests/fixtures/*'"'"' -exec chmod +x {} +\n\n' "$root"
}

cmm_find_non_executable_scripts() {
  local root="${1:-${CMM_ROOT}}"
  find "$root" -type f \( -name '*.sh' -o -name 'cmm' -o -name 'install.sh' -o -name 'uninstall.sh' \) \
    ! -path '*/tests/fixtures/*' ! -perm -111 2>/dev/null
}

# Offer to fix a single script or the whole repo. Returns 0 if fixed/executable.
cmm_offer_fix_permissions() {
  local script="$1"
  local root="${CMM_ROOT}"
  local reply

  if cmm_is_executable "$script"; then
    return 0
  fi

  cmm_log_error "Permission denied — not executable: $script"
  cmm_print_chmod_instructions "$root"

  if [[ ! -t 0 ]]; then
    cmm_log_error "Non-interactive mode: fix permissions manually, then retry."
    return 1
  fi

  printf 'Fix permissions automatically for all CleanMahMac scripts? [y/N] '
  if [[ -r /dev/tty ]]; then
    read -r reply </dev/tty
  else
    read -r reply
  fi
  case "$reply" in
    [yY]|[yY][eE][sS])
      cmm_chmod_repo_scripts "$root"
      if cmm_is_executable "$script"; then
        cmm_log_ok "Permissions fixed."
        return 0
      fi
      cmm_log_error "Could not fix permissions automatically."
      return 1
      ;;
    *)
      cmm_log_info "Skipped automatic fix. Run the command above, then retry."
      return 1
      ;;
  esac
}

cmm_exec_script() {
  local script="$1"
  shift
  if ! cmm_is_executable "$script"; then
    cmm_offer_fix_permissions "$script" || exit 1
  fi
  exec "$script" "$@"
}
