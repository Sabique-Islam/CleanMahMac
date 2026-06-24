#!/usr/bin/env bash
# shellcheck shell=bash
# Docker: build cache, dangling/unused images, stopped containers, optional volumes.

cmm_docker_cli_available() {
  cmm_tool_exists docker
}

cmm_docker_daemon_running() {
  cmm_docker_cli_available && docker info >/dev/null 2>&1
}

cmm_docker_log_daemon_stopped() {
  cmm_log_warn "Docker is installed but Docker Desktop is not running."
  cmm_log_info "Start Docker Desktop, then retry. Scanning Docker.raw on disk only."
}

cmm_scan_docker_raw_files() {
  local raw disk logical meta
  for raw in \
    "${HOME}/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw" \
    "${HOME}/Library/Containers/com.docker.docker/Data/vms/0/Docker.raw"; do
    [[ -f "$raw" ]] || continue
    disk="$(cmm_size_bytes "$raw")"
    if cmm_is_sparse_file "$raw"; then
      logical="$(cmm_logical_size_bytes "$raw")"
      meta="On disk: $(cmm_format_bytes "$disk") | Virtual disk cap: $(cmm_format_bytes "$logical") (sparse — ls/Finder shows virtual size)"
      cmm_add_scan_result "docker" "Docker.raw VM disk" "$raw" "$disk" "$meta"
    else
      cmm_add_scan_result "docker" "Docker.raw VM disk" "$raw" "$disk"
    fi
  done
}

cmm_scan_docker() {
  if ! cmm_docker_cli_available; then
    cmm_log_warn "Docker CLI not found — skipping daemon cleanup (Docker.raw still checked if present)"
    cmm_scan_docker_raw_files
    return 0
  fi

  if ! cmm_docker_daemon_running; then
    cmm_docker_log_daemon_stopped
    cmm_scan_docker_raw_files
    return 0
  fi

  local reclaimable
  reclaimable="$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || true)"
  if [[ -n "$reclaimable" ]]; then
    cmm_add_scan_result "docker" "Docker reclaimable" "(docker system prune)" "0" "Estimated: $reclaimable"
  fi

  cmm_scan_docker_raw_files

  local vol
  while IFS= read -r vol; do
    [[ -n "$vol" ]] || continue
    cmm_add_scan_result "docker" "Orphaned volume" "$vol" "0" "(unused volume — use --volumes to include)"
  done < <(docker volume ls -qf dangling=true 2>/dev/null || true)
}

cmm_clean_docker() {
  if ! cmm_docker_cli_available; then
    cmm_log_warn "Docker CLI not found — install Docker Desktop to use this module"
    return 0
  fi

  if ! cmm_docker_daemon_running; then
    cmm_docker_log_daemon_stopped
    cmm_log_warn "Cannot prune images/containers until the daemon is running."
    cmm_scan_docker_raw_files
    if ((${#CMM_SCAN_RESULTS[@]} > 0)); then
      cmm_log_section "On-disk Docker data"
      cmm_print_scan_results
    fi
    return 0
  fi

  cmm_log_section "Docker cleanup"

  if [[ "${CMM_DRY_RUN:-1}" == "1" ]]; then
    cmm_log_dry "Would run: docker system prune -f"
    docker system df 2>/dev/null || true
    if [[ "${CMM_DOCKER_VOLUMES:-0}" == "1" ]]; then
      cmm_log_dry "Would also prune unused volumes"
    fi
    return 0
  fi

  cmm_confirm "Prune Docker build cache, dangling images, and stopped containers?" 1 || return 1

  docker system prune -f
  if [[ "${CMM_DOCKER_VOLUMES:-0}" == "1" ]]; then
    cmm_confirm "Also prune unused Docker volumes?" 1 && docker volume prune -f
  fi
  cmm_log_ok "Docker cleanup complete"
}
