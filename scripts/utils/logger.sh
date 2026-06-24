#!/usr/bin/env bash
# shellcheck shell=bash
# Structured logging for CleanMahMac.

: "${CMM_LOG_PREFIX:=cmm}"

cmm_log_info() {
  printf '%s %s\n' "$(cmm_color_blue "[${CMM_LOG_PREFIX}]")" "$*"
}

cmm_log_ok() {
  printf '%s %s\n' "$(cmm_color_green "[${CMM_LOG_PREFIX}]")" "$*"
}

cmm_log_warn() {
  printf '%s %s\n' "$(cmm_color_yellow "[${CMM_LOG_PREFIX}]")" "$*" >&2
}

cmm_log_error() {
  printf '%s %s\n' "$(cmm_color_red "[${CMM_LOG_PREFIX}]")" "$*" >&2
}

cmm_log_dry() {
  printf '%s %s\n' "$(cmm_color_cyan "[dry-run]")" "$*"
}

cmm_log_action() {
  printf '%s %s\n' "$(cmm_color_bold "[action]")" "$*"
}

cmm_log_section() {
  printf '\n%s %s\n' "$(cmm_color_bold "==>")" "$*"
}
