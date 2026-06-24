#!/usr/bin/env bash
# shellcheck shell=bash
# Interactive confirmation before destructive actions.

cmm_confirm() {
  local prompt="${1:-Proceed?}"
  local default_no="${2:-1}"

  if [[ "${CMM_YES:-0}" == "1" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    cmm_log_error "Refusing destructive action in non-interactive mode without --yes"
    return 1
  fi

  local reply
  if [[ "$default_no" == "1" ]]; then
    printf '%s [y/N] ' "$prompt"
  else
    printf '%s [Y/n] ' "$prompt"
  fi
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS]) return 0 ;;
    [nN]|[nN][oO]) return 1 ;;
    *)
      if [[ "$default_no" == "1" ]]; then return 1; else return 0; fi
      ;;
  esac
}

cmm_confirm_destructive() {
  local total_bytes="$1"
  local item_count="$2"
  local summary

  summary="$(cmm_format_bytes "$total_bytes") across $item_count item(s)"
  cmm_log_warn "About to permanently delete $summary"
  cmm_confirm "Type 'y' to confirm deletion" 1
}
