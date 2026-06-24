#!/usr/bin/env bash
# shellcheck shell=bash
# Color helpers for terminal output.

if [[ -t 1 ]]; then
  CMM_RED='\033[0;31m'
  CMM_GREEN='\033[0;32m'
  CMM_YELLOW='\033[1;33m'
  CMM_BLUE='\033[0;34m'
  CMM_CYAN='\033[0;36m'
  CMM_BOLD='\033[1m'
  CMM_DIM='\033[2m'
  CMM_RESET='\033[0m'
else
  CMM_RED=''
  CMM_GREEN=''
  CMM_YELLOW=''
  CMM_BLUE=''
  CMM_CYAN=''
  CMM_BOLD=''
  CMM_DIM=''
  CMM_RESET=''
fi

cmm_color_red()    { printf '%b%s%b' "$CMM_RED" "$*" "$CMM_RESET"; }
cmm_color_green()  { printf '%b%s%b' "$CMM_GREEN" "$*" "$CMM_RESET"; }
cmm_color_yellow() { printf '%b%s%b' "$CMM_YELLOW" "$*" "$CMM_RESET"; }
cmm_color_blue()   { printf '%b%s%b' "$CMM_BLUE" "$*" "$CMM_RESET"; }
cmm_color_cyan()   { printf '%b%s%b' "$CMM_CYAN" "$*" "$CMM_RESET"; }
cmm_color_bold()   { printf '%b%s%b' "$CMM_BOLD" "$*" "$CMM_RESET"; }
cmm_color_dim()    { printf '%b%s%b' "$CMM_DIM" "$*" "$CMM_RESET"; }
