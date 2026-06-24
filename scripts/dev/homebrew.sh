#!/usr/bin/env bash
# shellcheck shell=bash
# Homebrew: cleanup, autoremove, old downloads.

cmm_scan_homebrew() {
  if ! cmm_tool_exists brew; then
    cmm_log_warn "Homebrew not installed — skipping"
    return 0
  fi

  local cache="${HOME}/Library/Caches/Homebrew"
  [[ -d "$cache" ]] && cmm_add_scan_result "homebrew" "Homebrew download cache" "$cache"

  local reclaimable
  reclaimable="$(brew cleanup -n -s 2>/dev/null | tail -1 || true)"
  if [[ -n "$reclaimable" ]]; then
    cmm_add_scan_result "homebrew" "Homebrew old versions" "(brew cleanup)" "0" "$reclaimable"
  fi
}

cmm_clean_homebrew() {
  if ! cmm_tool_exists brew; then
    cmm_log_warn "Homebrew not installed"
    return 0
  fi

  cmm_log_section "Homebrew cleanup"

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Would run: brew cleanup -s && brew autoremove"
    brew cleanup -n -s 2>/dev/null || true
    return 0
  fi

  cmm_confirm "Run Homebrew cleanup and autoremove?" 1 || return 1
  brew cleanup -s
  brew autoremove 2>/dev/null || true
  cmm_log_ok "Homebrew cleanup complete"
}
