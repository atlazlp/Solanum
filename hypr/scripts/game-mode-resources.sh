#!/usr/bin/env bash
# Shell-driven game mode hook: `stop` = enter game mode (marker + pause the center video), `start` = leave it.
# features/gamemode.lua does the same from inside Hyprland; both use the quantum-moon-game-mode.active marker.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
ACTIVE_MARKER="${XDG_RUNTIME_DIR:-/tmp}/quantum-moon-game-mode.active"

pause_center_video() {
	local want="$1"
	[[ -x "${SCRIPT_DIR}/qm-mpv-ipc" ]] || return 0
	"${SCRIPT_DIR}/qm-mpv-ipc" pause "${want}" || true
}

game_mode_stop() {
	touch "$ACTIVE_MARKER"
	pause_center_video true
}

game_mode_start() {
	rm -f "$ACTIVE_MARKER"
	pause_center_video false
}

case "${1:-}" in
stop) game_mode_stop ;;
start) game_mode_start ;;
*)
	echo "usage: $0 stop|start" >&2
	exit 1
	;;
esac
