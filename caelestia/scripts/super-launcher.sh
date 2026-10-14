#!/usr/bin/env bash
# Hyprland 0.55+/0.56: bindi + catchall + GlobalShortcut is broken (catchall also
# matches Super_L itself, so launcherInterrupted stays true). Drive the launcher
# via shell IPC with a small press/interrupt/release state machine instead.
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/caelestia-super-launcher.state"
# Ignore catchall echoes of Super_L/Super_R within this window (ns).
IGNORE_NS=100000000

cmd="${1:?press|interrupt|release}"

now_ns() {
  date +%s%N
}

case "${cmd}" in
  press)
    printf '0 %s\n' "$(now_ns)" >"${STATE}"
    ;;
  interrupt)
    if [[ ! -f "${STATE}" ]]; then
      exit 0
    fi
    # shellcheck disable=SC2034
    read -r interrupted ts <"${STATE}" || exit 0
    now="$(now_ns)"
    if [[ -n "${ts}" ]] && ((now - ts > IGNORE_NS)); then
      printf '1 %s\n' "${ts}" >"${STATE}"
    fi
    ;;
  release)
    if [[ ! -f "${STATE}" ]]; then
      exit 0
    fi
    read -r interrupted _ts <"${STATE}" || true
    rm -f "${STATE}"
    if [[ "${interrupted}" == "0" ]]; then
      caelestia shell drawers toggle launcher
    fi
    ;;
  *)
    echo "usage: $0 press|interrupt|release" >&2
    exit 2
    ;;
esac
