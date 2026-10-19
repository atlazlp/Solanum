#!/usr/bin/env bash
# Shell-driven game mode hook: `stop` = enter game mode, `start` = leave it.
# Enter: marker + pause mpv + quit Godot wallpaper.
# Leave: clear marker + restart last wallpaper (Godot scene or mpvpaper).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
ACTIVE_MARKER="${XDG_RUNTIME_DIR:-/tmp}/solanum-game-mode.active"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/solanum"

# Prefer repo bin/ for qm-* helpers (same tree as this hypr/scripts).
BIN_DIR="$(cd "${SCRIPT_DIR}/../../bin" 2>/dev/null && pwd || true)"
if [[ -n "${BIN_DIR}" && -x "${BIN_DIR}/qm-video-restart" ]]; then
	export PATH="${BIN_DIR}:${PATH}"
fi

# shellcheck source=/dev/null
if [[ -f "${BIN_DIR}/qm-video-lib.sh" ]]; then
	# bin/ is often a thin wrapper; real lib lives under solanum/scripts
	:
fi
LIB=""
for cand in \
	"${SCRIPT_DIR}/../../solanum/scripts/qm-video-lib.sh" \
	"${SCRIPT_DIR}/../../bin/qm-video-lib.sh"; do
	if [[ -f "${cand}" ]]; then
		LIB="${cand}"
		break
	fi
done
if [[ -n "${LIB}" ]]; then
	# shellcheck source=/dev/null
	source "${LIB}"
fi

pause_center_video() {
	local want="$1"
	if command -v qm-mpv-ipc >/dev/null 2>&1; then
		qm-mpv-ipc pause "${want}" || true
	elif [[ -x "${SCRIPT_DIR}/qm-mpv-ipc" ]]; then
		"${SCRIPT_DIR}/qm-mpv-ipc" pause "${want}" || true
	fi
}

game_mode_stop() {
	touch "$ACTIVE_MARKER"
	pause_center_video true
	if declare -F qm_godot_stop >/dev/null 2>&1; then
		qm_godot_stop || true
	elif command -v qm-godot-stop >/dev/null 2>&1; then
		qm-godot-stop || true
	else
		# Fallback: kill by pidfile / class
		local pf="${STATE_DIR}/godot-wallpaper.pid"
		if [[ -f "${pf}" ]]; then
			local pid
			pid="$(cat "${pf}" 2>/dev/null || true)"
			[[ -n "${pid}" ]] && kill "${pid}" 2>/dev/null || true
			rm -f "${pf}"
		fi
		if command -v hyprctl >/dev/null 2>&1; then
			hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class=="qm-solar-wallpaper") | .address' 2>/dev/null \
				| while read -r addr; do
					[[ -n "${addr}" ]] && hyprctl dispatch closewindow "address:${addr}" >/dev/null 2>&1 || true
				done
		fi
	fi
}

game_mode_start() {
	rm -f "$ACTIVE_MARKER"
	pause_center_video false
	local slug=""
	if [[ -f "${STATE_DIR}/last-video.slug" ]]; then
		slug="$(tr -d '\n' <"${STATE_DIR}/last-video.slug")"
	fi
	[[ -n "${slug}" ]] || slug="brittle-hollow"
	if command -v qm-video-restart >/dev/null 2>&1; then
		qm-video-restart "${slug}" || true
	elif [[ -x "${BIN_DIR}/qm-video-restart" ]]; then
		"${BIN_DIR}/qm-video-restart" "${slug}" || true
	fi
}

case "${1:-}" in
stop) game_mode_stop ;;
start) game_mode_start ;;
*)
	echo "usage: $0 stop|start" >&2
	exit 1
	;;
esac
