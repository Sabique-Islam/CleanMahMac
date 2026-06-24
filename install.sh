#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-${HOME}/.local/bin}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${INSTALL_DIR}/cmm"
LINK_TARGET="${REPO_ROOT}/cmm"

cmm_install_chmod_scripts() {
  find "$REPO_ROOT" -type f \( -name '*.sh' -o -name 'cmm' -o -name 'install.sh' -o -name 'uninstall.sh' \) \
    ! -path '*/tests/fixtures/*' -exec chmod +x {} +
}

main() {
  mkdir -p "$INSTALL_DIR"

  if ! cmm_install_chmod_scripts; then
    cat <<EOF >&2
Error: Could not set execute permissions on scripts.

Your repo may be read-only. Run this manually, then re-run ./install.sh:

  chmod +x ${REPO_ROOT}/cmm ${REPO_ROOT}/install.sh ${REPO_ROOT}/uninstall.sh
  find ${REPO_ROOT} -type f \\( -name '*.sh' -o -name cmm \\) ! -path '*/tests/fixtures/*' -exec chmod +x {} +

EOF
    exit 1
  fi

  if [[ -e "$TARGET" ]] && [[ ! -L "$TARGET" ]]; then
    printf 'Error: %s exists and is not a symlink.\n' "$TARGET" >&2
    exit 1
  fi

  ln -sf "$LINK_TARGET" "$TARGET"

  cat <<EOF

CleanMahMac installed.

  Command: cmm
  Binary:   $TARGET
  Repo:     $REPO_ROOT

Make sure $INSTALL_DIR is on your PATH:

  export PATH="$INSTALL_DIR:\$PATH"

Try it:

  cmm configure
  cmm scan
  cmm doctor

If a command fails with "Permission denied", run:

  cmm fix-permissions

Dry-run is the default. Your source code is safe. Probably.
EOF
}

main "$@"
