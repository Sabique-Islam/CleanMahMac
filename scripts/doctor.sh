#!/usr/bin/env bash
# shellcheck shell=bash
# Doctor: detect space hogs and anomalies without deleting.

set -euo pipefail

# shellcheck source=scripts/utils/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/utils/common.sh"
# shellcheck source=scripts/dev/docker.sh
source "${CMM_ROOT}/scripts/dev/docker.sh"
# shellcheck source=scripts/dev/abandoned-node-modules.sh
source "${CMM_ROOT}/scripts/dev/abandoned-node-modules.sh"

CMM_DOCTOR_ISSUES=0

cmm_doctor_issue() {
  local severity="$1"
  local title="$2"
  local detail="$3"
  CMM_DOCTOR_ISSUES=$((CMM_DOCTOR_ISSUES + 1))
  case "$severity" in
    warn) printf '%s %s\n   %s\n' "$(cmm_color_yellow "[warn]")" "$title" "$detail" ;;
    info) printf '%s %s\n   %s\n' "$(cmm_color_blue "[info]")" "$title" "$detail" ;;
    *)    printf '%s %s\n   %s\n' "$(cmm_color_red "[critical]")" "$title" "$detail" ;;
  esac
}

cmm_doctor_check_docker_raw() {
  local warn_gb
  warn_gb="$(cmm_read_json_default "doctor.docker_raw_warn_gb" "50")"
  local raw disk logical disk_gb logical_gb
  for raw in \
    "${HOME}/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw" \
    "${HOME}/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw"; do
    [[ -f "$raw" ]] || continue
    disk="$(cmm_size_bytes "$raw")"
    disk_gb=$(awk -v b="$disk" 'BEGIN {printf "%.1f", b/1024/1024/1024}')
    if cmm_is_sparse_file "$raw"; then
      logical="$(cmm_logical_size_bytes "$raw")"
      logical_gb=$(awk -v b="$logical" 'BEGIN {printf "%.1f", b/1024/1024/1024}')
      cmm_doctor_issue "info" \
        "Docker.raw: ${disk_gb} GB on disk (${logical_gb} GB virtual cap — not cloud, local sparse file)" \
        "$raw — Finder/ls show virtual size; prune with Docker running to shrink actual usage"
    elif awk -v g="$disk_gb" -v w="$warn_gb" 'BEGIN {exit !(g+0 >= w+0)}'; then
      cmm_doctor_issue "warn" "Large Docker.raw (${disk_gb} GB on disk)" \
        "$raw — start Docker Desktop and run 'cmm clean docker --force'"
    fi
  done
}

cmm_doctor_check_simulators() {
  local sim_dir="${HOME}/Library/Developer/CoreSimulator/Devices"
  [[ -d "$sim_dir" ]] || return 0
  local count
  count="$(find "$sim_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  if (( count > 20 )); then
    cmm_doctor_issue "warn" "$count iOS simulators installed" "Run 'xcrun simctl delete unavailable' or 'cmm clean xcode'"
  fi
}

cmm_doctor_check_abandoned() {
  cmm_reset_scan
  cmm_run_module_scan "abandoned-node-modules"
  if ((${#CMM_SCAN_RESULTS[@]} > 0)); then
    cmm_doctor_issue "info" \
      "$(cmm_format_bytes "$CMM_SCAN_TOTAL_BYTES") in abandoned node_modules" \
      "${#CMM_SCAN_RESULTS[@]} project(s) idle >$(cmm_abandoned_threshold_days) days — run 'cmm report' or 'cmm clean abandoned-node-modules'"
  fi
}

cmm_doctor_check_logs() {
  local warn_mb
  warn_mb="$(cmm_read_json_default "doctor.log_file_warn_mb" "500")"
  local log bytes mb
  while IFS= read -r log; do
    [[ -n "$log" ]] || continue
    bytes="$(cmm_size_bytes "$log")"
    mb=$(awk -v b="$bytes" 'BEGIN {printf "%.0f", b/1024/1024}')
    if (( mb >= warn_mb )); then
      cmm_doctor_issue "warn" "Large log file (${mb} MB)" "$log"
    fi
  done < <(find "${HOME}/Library/Logs" -type f -size +100M 2>/dev/null | head -20 || true)
}

cmm_doctor_check_duplicate_sdks() {
  local sdk="${HOME}/Library/Android/sdk"
  [[ -d "$sdk" ]] || return 0
  local platforms
  platforms="$(find "$sdk/platforms" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  local images
  images="$(find "$sdk/system-images" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  if (( platforms > 8 || images > 10 )); then
    cmm_doctor_issue "info" "Multiple Android SDK versions ($platforms platforms, $images image dirs)" \
      "Review with Android Studio SDK Manager or 'cmm clean android'"
  fi
}

cmm_doctor_check_cache_growth() {
  local warn_gb
  warn_gb="$(cmm_read_json_default "doctor.cache_growth_warn_gb" "10")"
  local path bytes gb
  for path in \
    "${HOME}/Library/Developer/Xcode/DerivedData" \
    "${HOME}/.gradle/caches" \
    "${HOME}/.npm" \
    "${HOME}/Library/Caches/Homebrew"; do
    [[ -e "$path" ]] || continue
    bytes="$(cmm_size_bytes "$path")"
    gb=$(awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1024/1024/1024}')
    if awk -v g="$gb" -v w="$warn_gb" 'BEGIN {exit !(g+0 >= w+0)}'; then
      cmm_doctor_issue "warn" "Large cache: $(basename "$path") ($gb GB)" "$path"
    fi
  done
}

cmm_doctor_check_docker_daemon() {
  if cmm_docker_cli_available && ! cmm_docker_daemon_running; then
    cmm_doctor_issue "info" "Docker Desktop is not running" \
      "Start Docker Desktop to scan/prune images and containers; Docker.raw is still checked on disk"
  fi
}

cmm_doctor_check_docker_volumes() {
  if ! cmm_docker_daemon_running; then
    return 0
  fi
  local count
  count="$(docker volume ls -qf dangling=true 2>/dev/null | wc -l | tr -d ' ')"
  if (( count > 0 )); then
    cmm_doctor_issue "info" "$count orphaned Docker volume(s)" "Run 'cmm clean docker --volumes --force'"
  fi
}

cmm_doctor_check_archives() {
  local archives="${HOME}/Library/Developer/Xcode/Archives"
  [[ -d "$archives" ]] || return 0
  local bytes gb count
  bytes="$(cmm_size_bytes "$archives")"
  gb=$(awk -v b="$bytes" 'BEGIN {printf "%.1f", b/1024/1024/1024}')
  count="$(find "$archives" -maxdepth 2 -name "*.xcarchive" 2>/dev/null | wc -l | tr -d ' ')"
  if awk -v g="$gb" 'BEGIN {exit !(g+0 >= 5)}'; then
    cmm_doctor_issue "warn" "Large Xcode archives ($gb GB, $count archive(s))" "$archives"
  fi
}

cmm_doctor_check_script_permissions() {
  local script count=0
  while IFS= read -r script; do
    [[ -n "$script" ]] || continue
    count=$((count + 1))
    cmm_doctor_issue "warn" "Script not executable" "$script"
  done < <(cmm_find_non_executable_scripts "${CMM_ROOT}")
  if (( count > 0 )); then
    cmm_doctor_issue "info" "$count script(s) missing +x" "Run 'cmm fix-permissions' to fix"
  fi
}

cmm_doctor_main() {
  printf '\n%s\n\n' "$(cmm_color_bold "CleanMahMac Doctor")"
  cmm_log_info "Checking for disk space hogs and dev-environment anomalies..."

  cmm_doctor_check_script_permissions
  cmm_doctor_check_docker_daemon
  cmm_doctor_check_docker_raw
  cmm_doctor_check_simulators
  cmm_doctor_check_abandoned
  cmm_doctor_check_logs
  cmm_doctor_check_duplicate_sdks
  cmm_doctor_check_cache_growth
  cmm_doctor_check_docker_volumes
  cmm_doctor_check_archives

  printf '\n'
  if (( CMM_DOCTOR_ISSUES == 0 )); then
    cmm_log_ok "No issues detected. Suspiciously healthy."
  else
    cmm_log_info "Found $CMM_DOCTOR_ISSUES issue(s). Run 'cmm scan' for reclaimable totals."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmm_doctor_main "$@"
fi
