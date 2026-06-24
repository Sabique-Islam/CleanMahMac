#!/usr/bin/env bash
# shellcheck shell=bash
# Abandoned node_modules: the feature you actually came for.

cmm_abandoned_threshold_days() {
  cmm_read_json_default "abandoned_days" "15"
}

cmm_is_node_project() {
  local dir="$1"
  [[ -f "${dir}/package.json" ]] || \
  [[ -f "${dir}/pnpm-lock.yaml" ]] || \
  [[ -f "${dir}/yarn.lock" ]] || \
  [[ -f "${dir}/package-lock.json" ]]
}

cmm_find_abandoned_projects() {
  local threshold="$1"
  local root expanded marker project nm days bytes

  for root in "${CMM_USER_SCAN_ROOTS[@]}"; do
    [[ -n "$root" ]] || continue
    expanded="$(cmm_expand_tilde "$root")"
    [[ -d "$expanded" ]] || continue

    while IFS= read -r marker; do
      [[ -n "$marker" ]] || continue
      project="$(dirname "$marker")"
      cmm_is_node_project "$project" || continue

      nm="${project}/node_modules"
      [[ -d "$nm" ]] || continue

      days="$(cmm_days_since_activity "$project")"
      if (( days < threshold )); then
        continue
      fi

      bytes="$(cmm_size_bytes "$nm")"
      if (( bytes <= 0 )); then
        continue
      fi

      local meta
      meta="Last active: $(cmm_format_days_ago "$days")"
      cmm_add_scan_result "abandoned-node-modules" "node_modules" "$nm" "$bytes" "$meta|project:${project}"
    done < <(find "$expanded" -maxdepth 6 \( \
      -name package.json -o -name pnpm-lock.yaml -o \
      -name yarn.lock -o -name package-lock.json \
    \) 2>/dev/null || true)
  done
}

cmm_scan_abandoned_node_modules() {
  cmm_ensure_scan_roots || return 0
  cmm_find_abandoned_projects "$(cmm_abandoned_threshold_days)"
}

cmm_print_abandoned_report() {
  local entry path bytes meta project
  local seen_projects=""

  if ((${#CMM_SCAN_RESULTS[@]} == 0)); then
    cmm_log_ok "No abandoned node_modules found (threshold: $(cmm_abandoned_threshold_days) days)"
    return 0
  fi

  printf '\n%s\n\n' "$(cmm_color_bold "Found abandoned projects")"

  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path bytes meta <<< "$entry"
    project="${meta#*project:}"
    meta="${meta%|project:*}"

    case "$seen_projects" in
      *"|${project}|"*) continue ;;
    esac
    seen_projects="${seen_projects}|${project}|"

    printf '%s\n' "$project"
    printf '%s\n' "$meta"
    printf 'node_modules: %s\n\n' "$(cmm_format_bytes "$bytes")"
  done

  printf '%s %s\n' "$(cmm_color_bold "Total reclaimable:")" "$(cmm_format_bytes "$CMM_SCAN_TOTAL_BYTES")"
}

cmm_clean_abandoned_node_modules() {
  cmm_reset_scan
  cmm_ensure_scan_roots 1 || return 0
  cmm_find_abandoned_projects "$(cmm_abandoned_threshold_days)"
  local total="$CMM_SCAN_TOTAL_BYTES"
  local count="${#CMM_SCAN_RESULTS[@]}"

  cmm_print_abandoned_report

  if (( count == 0 )); then
    return 0
  fi

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Re-run with --force to delete after review"
    return 0
  fi

  cmm_log_warn "This removes node_modules only — your source code stays put."
  cmm_confirm_destructive "$total" "$count" || return 1

  local entry path project
  for entry in "${CMM_SCAN_RESULTS[@]}"; do
    IFS='|' read -r _ _ path _ meta <<< "$entry"
    project="${meta#*project:}"
    cmm_log_action "Removing node_modules in $project"
    cmm_safe_remove "$path" 1 || cmm_log_warn "Skipped: $path"
  done
  cmm_log_ok "Abandoned node_modules cleanup complete — reclaimed $(cmm_format_bytes "$total")"
}
