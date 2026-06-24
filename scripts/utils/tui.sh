#!/usr/bin/env bash
# shellcheck shell=bash
# Minimal terminal UI — arrow-key multiselect on /dev/tty (Bash 3.2 / macOS).

CMM_TUI_SELECTED=()

cmm_tui_tty() {
  if [[ -r /dev/tty ]] && [[ -w /dev/tty ]]; then
    printf '/dev/tty'
  fi
}

cmm_tui_hide_cursor() {
  local tty
  tty="$(cmm_tui_tty)"
  [[ -n "$tty" ]] && printf '\033[?25l' >"$tty"
}

cmm_tui_show_cursor() {
  local tty
  tty="$(cmm_tui_tty)"
  [[ -n "$tty" ]] && printf '\033[?25h' >"$tty"
}

cmm_tui_read_key() {
  local tty key seq1 seq2
  tty="$(cmm_tui_tty)"
  IFS= read -rsn1 key <"$tty"
  if [[ "$key" == $'\e' ]]; then
    # Bash 3.2 (macOS) requires integer -t; read rest of escape sequence byte-by-byte.
    if IFS= read -rsn1 -t 1 seq1 <"$tty"; then
      if [[ "$seq1" == '[' ]] || [[ "$seq1" == 'O' ]]; then
        IFS= read -rsn1 seq2 <"$tty"
        key="${key}${seq1}${seq2}"
      else
        key="${key}${seq1}"
      fi
    fi
  fi
  printf '%s' "$key"
}

# Multiselect menu. Args: title, then item labels.
# Sets CMM_TUI_SELECTED to chosen labels. Returns 1 on cancel (q).
cmm_tui_multiselect() {
  local title="$1"
  shift
  local items=("$@")
  local count="${#items[@]}"
  local cursor=0
  local i key tty
  local checked=()

  CMM_TUI_SELECTED=()

  if [[ "$count" -eq 0 ]]; then
    return 1
  fi

  tty="$(cmm_tui_tty)"
  if [[ -z "$tty" ]]; then
    return 1
  fi

  for ((i = 0; i < count; i++)); do
    checked[i]=0
  done

  cmm_tui_hide_cursor

  while true; do
    {
      printf '\033[2J\033[H'
      printf '%s\n\n' "$title"
      printf '%s\n\n' "↑/↓ move   Space toggle   Enter confirm   q cancel"
      for ((i = 0; i < count; i++)); do
        local marker cursor_prefix
        if [[ "${checked[i]}" == "1" ]]; then
          marker="(x)"
        else
          marker="( )"
        fi
        if (( i == cursor )); then
          cursor_prefix=">"
        else
          cursor_prefix=" "
        fi
        printf '%s %s %s\n' "$cursor_prefix" "$marker" "${items[i]}"
      done
    } >"$tty"

    key="$(cmm_tui_read_key)"
    case "$key" in
      $'\e[A'|$'\eOA'|k|K)
        if (( cursor > 0 )); then
          cursor=$((cursor - 1))
        fi
        ;;
      $'\e[B'|$'\eOB'|j|J)
        if (( cursor < count - 1 )); then
          cursor=$((cursor + 1))
        fi
        ;;
      ' ')
        if [[ "${checked[cursor]}" == "1" ]]; then
          checked[cursor]=0
        else
          checked[cursor]=1
        fi
        ;;
      ''|$'\n'|$'\r')
        for ((i = 0; i < count; i++)); do
          if [[ "${checked[i]}" == "1" ]]; then
            CMM_TUI_SELECTED+=("${items[i]}")
          fi
        done
        cmm_tui_show_cursor
        printf '\n' >"$tty"
        return 0
        ;;
      q|Q|$'\e')
        cmm_tui_show_cursor
        printf '\n' >"$tty"
        return 1
        ;;
    esac
  done
}
