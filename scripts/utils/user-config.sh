#!/usr/bin/env bash
# shellcheck shell=bash
# User-specific configuration (scan roots, etc.)

cmm_init_scan_roots() {
  if [[ -z "${CMM_USER_SCAN_ROOTS+set}" ]]; then
    CMM_USER_SCAN_ROOTS=()
  fi
}

CMM_DISCOVERED_SCAN_ROOTS=()

cmm_user_config_dir() {
  printf '%s/.config/cleanmahmac' "$HOME"
}

cmm_scan_roots_file() {
  printf '%s/scan-roots.txt' "$(cmm_user_config_dir)"
}

cmm_ensure_user_config_dir() {
  mkdir -p "$(cmm_user_config_dir)"
}

cmm_default_scan_root_suggestions() {
  printf '%s\n' \
    "~/Projects" \
    "~/Code" \
    "~/Workspace" \
    "~/Developer" \
    "~/Documents" \
    "~/Downloads"
}

cmm_expand_tilde() {
  local p="$1"
  printf '%s' "${p/#\~/$HOME}"
}

cmm_to_tilde_path() {
  local p="$1"
  if [[ "$p" == "$HOME" ]]; then
    printf '~'
  elif [[ "$p" == "$HOME/"* ]]; then
    printf '~/%s' "${p#"$HOME/"}"
  else
    printf '%s' "$p"
  fi
}

cmm_dir_has_node_project() {
  local dir="$1"
  find "$dir" -maxdepth 4 \( \
    -name package.json -o -name pnpm-lock.yaml -o \
    -name yarn.lock -o -name package-lock.json \
  \) -print -quit 2>/dev/null | grep -q .
}

cmm_discover_scan_root_candidates() {
  local suggestion expanded top key path
  local seen=""

  CMM_DISCOVERED_SCAN_ROOTS=()

  while IFS= read -r suggestion; do
    [[ -n "$suggestion" ]] || continue
    expanded="$(cmm_expand_tilde "$suggestion")"
    if [[ -d "$expanded" ]]; then
      key="$(cmm_expand_path "$expanded")"
      case "$seen" in
        *"|${key}|"*) ;;
        *)
          seen="${seen}|${key}|"
          CMM_DISCOVERED_SCAN_ROOTS+=("$(cmm_to_tilde_path "$key")")
          ;;
      esac
    fi
  done < <(cmm_default_scan_root_suggestions)

  for top in "$HOME"/*/; do
    [[ -d "$top" ]] || continue
    if cmm_dir_has_node_project "$top"; then
      path="${top%/}"
      key="$(cmm_expand_path "$path")"
      case "$seen" in
        *"|${key}|"*) ;;
        *)
          seen="${seen}|${key}|"
          CMM_DISCOVERED_SCAN_ROOTS+=("$(cmm_to_tilde_path "$key")")
          ;;
      esac
    fi
  done

  if ((${#CMM_DISCOVERED_SCAN_ROOTS[@]} > 1)); then
    local sorted
    sorted="$(printf '%s\n' "${CMM_DISCOVERED_SCAN_ROOTS[@]}" | sort -u)"
    CMM_DISCOVERED_SCAN_ROOTS=()
    while IFS= read -r path; do
      [[ -n "$path" ]] && CMM_DISCOVERED_SCAN_ROOTS+=("$path")
    done <<< "$sorted"
  fi
}

cmm_scan_roots_configured() {
  [[ -f "$(cmm_scan_roots_file)" ]] && [[ -s "$(cmm_scan_roots_file)" ]]
}

cmm_save_scan_roots() {
  local root
  cmm_ensure_user_config_dir
  : > "$(cmm_scan_roots_file)"
  for root in "$@"; do
    [[ -n "$root" ]] || continue
    printf '%s\n' "$root" >> "$(cmm_scan_roots_file)"
  done
}

cmm_load_saved_scan_roots() {
  cmm_init_scan_roots
  if ((${#CMM_USER_SCAN_ROOTS[@]} > 0)); then
    return 0
  fi
  local line
  CMM_USER_SCAN_ROOTS=()
  [[ -f "$(cmm_scan_roots_file)" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] || continue
    CMM_USER_SCAN_ROOTS+=("$line")
  done < "$(cmm_scan_roots_file)"
}

cmm_configure_scan_roots_interactive() {
  local selected reply

  if [[ ! -t 0 ]] || [[ -z "$(cmm_tui_tty)" ]]; then
    cmm_log_error "Interactive terminal required. Run 'cmm configure' in a terminal."
    return 1
  fi

  while true; do
    cmm_discover_scan_root_candidates

    if ((${#CMM_DISCOVERED_SCAN_ROOTS[@]} == 0)); then
      cmm_log_error "No dev folders found. Create a project folder first, then run 'cmm configure'."
      return 1
    fi

    cmm_log_section "Configure scan folders"
    printf '%s\n\n' "Choose where to look for abandoned node_modules."
    printf '%s\n\n' "Only node_modules inside Node projects are ever removed — never your source files."

    if ! cmm_tui_multiselect "Select scan folders (↑/↓ move, Space toggle, Enter confirm)" "${CMM_DISCOVERED_SCAN_ROOTS[@]}"; then
      cmm_log_warn "Configuration cancelled."
      return 1
    fi

    if ((${#CMM_TUI_SELECTED[@]} == 0)); then
      cmm_log_warn "No folders selected. Select at least one with Space, then press Enter."
      continue
    fi

    printf '\n%s\n' "$(cmm_color_bold "Selected folders:")"
    for selected in "${CMM_TUI_SELECTED[@]}"; do
      printf '  • %s\n' "$selected"
    done
    printf '\n'

    if ! cmm_confirm "Save these scan folders?" 1; then
      cmm_log_info "Returning to folder picker..."
      continue
    fi

    cmm_save_scan_roots "${CMM_TUI_SELECTED[@]}"
    cmm_log_ok "Saved ${#CMM_TUI_SELECTED[@]} scan folder(s) to $(cmm_scan_roots_file)"
    return 0
  done
}

cmm_confirm_scan_roots() {
  local root expanded

  if [[ "${CMM_YES:-0}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    cmm_log_info "Using configured scan folders (non-interactive)"
    return 0
  fi

  cmm_log_info "Will scan these folders for abandoned node_modules:"
  for root in "${CMM_USER_SCAN_ROOTS[@]}"; do
    expanded="$(cmm_expand_tilde "$root")"
    if [[ -d "$expanded" ]]; then
      printf '  • %s\n' "$root"
    else
      printf '  • %s %s\n' "$root" "$(cmm_color_dim "(missing)")"
    fi
  done
  cmm_confirm "Proceed with scan?" 1
}

cmm_ensure_scan_roots() {
  local require_confirm="${1:-0}"

  cmm_init_scan_roots
  cmm_load_saved_scan_roots

  if ((${#CMM_USER_SCAN_ROOTS[@]} == 0)); then
    if [[ -t 0 ]] && [[ -n "$(cmm_tui_tty)" ]]; then
      cmm_log_warn "No scan folders configured yet."
      cmm_configure_scan_roots_interactive || return 1
      cmm_load_saved_scan_roots
    else
      cmm_log_warn "No scan folders configured — run 'cmm configure' (skipped in non-interactive mode)"
      return 1
    fi
  fi

  if [[ "$require_confirm" == "1" ]]; then
    cmm_confirm_scan_roots || return 1
  elif ((${#CMM_USER_SCAN_ROOTS[@]} > 0)); then
    cmm_log_info "Scan folders:"
    local root expanded
    for root in "${CMM_USER_SCAN_ROOTS[@]}"; do
      expanded="$(cmm_expand_tilde "$root")"
      if [[ -d "$expanded" ]]; then
        printf '  • %s\n' "$root"
      else
        printf '  • %s %s\n' "$root" "$(cmm_color_dim "(missing)")"
      fi
    done
  fi
}

cmm_abandoned_scan_roots() {
  cmm_ensure_scan_roots || return 1
  local root
  for root in "${CMM_USER_SCAN_ROOTS[@]}"; do
    printf '%s\n' "$root"
  done
}
