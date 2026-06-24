#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
TARGET="${INSTALL_DIR}/cmm"

main() {
  if [[ -L "$TARGET" ]]; then
    rm -f "$TARGET"
    printf 'Removed %s\n' "$TARGET"
  elif [[ -e "$TARGET" ]]; then
    printf 'Refusing to remove non-symlink: %s\n' "$TARGET" >&2
    exit 1
  else
    printf 'Nothing to uninstall at %s\n' "$TARGET"
  fi
}

main "$@"
