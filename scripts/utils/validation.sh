#!/usr/bin/env bash
# shellcheck shell=bash
# Path safety validation — never delete outside allowlist or inside protected paths.

cmm_expand_path() {
  local p="$1"
  # Expand ~ and resolve symlinks where possible.
  p="${p/#\~/$HOME}"
  if [[ -e "$p" ]]; then
    python3 -c "import os,sys; print(os.path.realpath(sys.argv[1]))" "$p" 2>/dev/null || printf '%s' "$p"
  else
    printf '%s' "$p"
  fi
}

cmm_load_path_list() {
  local file="$1"
  local line expanded
  CMM_PATH_LIST=()
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] || continue
    expanded="$(cmm_expand_path "$line")"
    CMM_PATH_LIST+=("$expanded")
  done < "$file"
}

cmm_is_protected_path() {
  local target="$1"
  local protected home
  target="$(cmm_expand_path "$target")"
  home="$(cmm_expand_path "~")"

  for protected in "${CMM_PATH_LIST[@]}"; do
    # Exact match — never delete these paths themselves (e.g. ~, ~/Downloads)
    if [[ "$target" == "$protected" ]]; then
      return 0
    fi
    # Prefix block for system paths only — not user home subfolders
    if [[ "$protected" != "$home" ]] && [[ "$protected" != "$home/"* ]]; then
      if [[ "$target" == "$protected/"* ]]; then
        return 0
      fi
    fi
  done
  return 1
}

cmm_is_safe_path() {
  local target="$1"
  local safe
  target="$(cmm_expand_path "$target")"
  for safe in "${CMM_PATH_LIST[@]}"; do
    if [[ "$target" == "$safe" ]] || [[ "$target" == "$safe/"* ]]; then
      return 0
    fi
  done
  return 1
}

cmm_validate_clean_target() {
  local target="$1"
  local protected_file safe_file

  protected_file="${CMM_ROOT}/configs/protected-paths.txt"
  safe_file="${CMM_ROOT}/configs/safe-paths.txt"

  cmm_load_path_list "$protected_file"
  if cmm_is_protected_path "$target"; then
    cmm_log_error "Refusing protected path: $target"
    return 1
  fi

  CMM_PATH_LIST=()
  cmm_load_path_list "$safe_file"
  if cmm_is_safe_path "$target"; then
    return 0
  fi

  # node_modules inside user-configured scan roots
  if [[ "$target" == */node_modules ]] || [[ "$target" == */node_modules/* ]]; then
    local parent="${target%/node_modules}"
    parent="${parent%/node_modules/*}"
    parent="$(cmm_expand_path "$parent")"
    cmm_load_saved_scan_roots
    if ((${#CMM_USER_SCAN_ROOTS[@]} > 0)); then
      local root expanded
      for root in "${CMM_USER_SCAN_ROOTS[@]}"; do
        expanded="$(cmm_expand_tilde "$root")"
        expanded="$(cmm_expand_path "$expanded")"
        if [[ "$parent" == "$expanded" ]] || [[ "$parent" == "$expanded/"* ]]; then
          return 0
        fi
      done
    fi
  fi

  cmm_log_error "Path not in safe allowlist: $target"
  return 1
}

cmm_safe_remove() {
  local target="$1"
  local force="${2:-0}"

  target="$(cmm_expand_path "$target")"
  cmm_validate_clean_target "$target" || return 1

  if [[ "$force" != "1" ]] && [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Would remove: $target ($(cmm_path_size "$target"))"
    return 0
  fi

  if [[ ! -e "$target" ]]; then
    cmm_log_warn "Already gone: $target"
    return 0
  fi

  cmm_log_action "Removing: $target ($(cmm_path_size "$target"))"

  if [[ -d "$target" ]]; then
    rm -r "$target"
  else
    rm "$target"
  fi
}
