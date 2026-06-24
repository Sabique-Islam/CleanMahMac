#!/usr/bin/env bash
# shellcheck shell=bash
# Disk size helpers.

# Returns bytes actually consumed on disk (handles sparse files like Docker.raw).
cmm_size_bytes() {
  local path="$1"
  local kb
  if [[ ! -e "$path" ]]; then
    printf '0'
    return 0
  fi
  kb="$(du -sk "$path" 2>/dev/null | awk '{print $1}')"
  if [[ -n "$kb" ]]; then
    printf '%d' $((kb * 1024))
    return 0
  fi
  stat -f '%z' "$path" 2>/dev/null || printf '0'
}

# Logical/file length from stat (can exceed disk usage for sparse files).
cmm_logical_size_bytes() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf '0'
    return 0
  fi
  stat -f '%z' "$path" 2>/dev/null || printf '0'
}

# True when a file's logical size is much larger than disk usage (e.g. Docker.raw).
cmm_is_sparse_file() {
  local path="$1"
  local disk logical
  [[ -f "$path" ]] || return 1
  disk="$(cmm_size_bytes "$path")"
  logical="$(cmm_logical_size_bytes "$path")"
  (( logical > 0 && disk > 0 && logical > disk * 2 ))
}

# Human-readable size from bytes.
cmm_format_bytes() {
  local bytes="${1:-0}"
  awk -v b="$bytes" '
    function human(x,    u, i) {
      split("B KB MB GB TB", u)
      i = 1
      while (x >= 1024 && i < 5) { x /= 1024; i++ }
      if (i == 1) printf "%d B", x
      else printf "%.1f %s", x, u[i]
    }
    BEGIN { human(b) }
  '
}

# Human-readable size for a path.
cmm_path_size() {
  cmm_format_bytes "$(cmm_size_bytes "$1")"
}

# Days since last access/modification of a path.
cmm_days_since_activity() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf '0'
    return 0
  fi
  local now mtime atime latest
  now=$(date +%s)
  mtime=$(stat -f '%m' "$path" 2>/dev/null || printf '0')
  atime=$(stat -f '%a' "$path" 2>/dev/null || printf '0')
  latest=$mtime
  if (( atime > latest )); then latest=$atime; fi
  if (( latest == 0 )); then
    printf '0'
    return 0
  fi
  printf '%d' $(( (now - latest) / 86400 ))
}

cmm_format_days_ago() {
  local days="$1"
  if (( days == 0 )); then
    printf 'today'
  elif (( days == 1 )); then
    printf '1 day ago'
  else
    printf '%s days ago' "$days"
  fi
}

# Sum bytes from newline-separated list.
cmm_sum_bytes() {
  awk '{s+=$1} END {print s+0}'
}
