#!/usr/bin/env bash
set -eu

# Markers live under $XDG_RUNTIME_DIR with the solanum- prefix. During the Caelestia -> solanum
# transition the live Caelestia shell (patches/.../IdleMonitors.qml) still reads caelestia-resume-grace.until
# and caelestia-audio-playback.active, so the resume grace is written to BOTH names and the audio release
# removes both. Drop the LEGACY_* lines after the Phase 3 cutover.
RT="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="${RT}/solanum-locked-sleep.pid"
ARM="${RT}/solanum-locked-sleep.arm"
WAS_ARMED="${RT}/solanum-locked-sleep.was-armed"
DELAY_FILE="${RT}/solanum-locked-sleep.delay"
GRACE_UNTIL="${RT}/solanum-resume-grace.until"
LEGACY_GRACE_UNTIL="${RT}/caelestia-resume-grace.until"
AUDIO_MARKER="${RT}/solanum-audio-playback.active"
LEGACY_AUDIO_MARKER="${RT}/caelestia-audio-playback.active"
AUDIO_INHIBIT_PID="${RT}/solanum-audio-inhibit.pid"
LEGACY_AUDIO_INHIBIT_PID="${RT}/caelestia-audio-inhibit.pid"
# Shell IPC prefix: the unit/env sets QM_SHELL_IPC="qs -c solanum ipc call" after the cutover.
QM_SHELL_IPC="${QM_SHELL_IPC:-qs -c caelestia ipc call}"
RESUME_GRACE_SEC="${QM_RESUME_GRACE_SEC:-${CAELESTIA_RESUME_GRACE_SEC:-300}}"

release_audio_sleep_block() {
	rm -f "${AUDIO_MARKER}" "${LEGACY_AUDIO_MARKER}" 2>/dev/null || true
	local pf
	for pf in "${AUDIO_INHIBIT_PID}" "${LEGACY_AUDIO_INHIBIT_PID}"; do
		if [[ -f "${pf}" ]]; then
			kill "$(<"${pf}")" 2>/dev/null || true
			rm -f "${pf}"
		fi
	done
	pkill -f 'systemd-inhibit.*--who=audio-playback' 2>/dev/null || true
}

within_resume_grace() {
	[[ -f "${GRACE_UNTIL}" ]] || return 1
	local until now
	until="$(<"${GRACE_UNTIL}")"
	now="$(date +%s)"
	[[ "${now}" -lt "${until}" ]]
}

set_resume_grace() {
	local grace="${1:-${RESUME_GRACE_SEC}}" until
	until="$(date -d "+${grace} seconds" +%s 2>/dev/null || echo $(( $(date +%s) + grace )))"
	echo "${until}" >"${GRACE_UNTIL}"
	echo "${until}" >"${LEGACY_GRACE_UNTIL}"
}

disarm() {
	if [[ -f "${PIDFILE}" ]]; then
		kill "$(<"${PIDFILE}")" 2>/dev/null || true
		rm -f "${PIDFILE}"
	fi
	rm -f "${ARM}"
}

is_locked() {
	command -v qs >/dev/null 2>&1 || return 1
	# shellcheck disable=SC2086
	${QM_SHELL_IPC} lock isLocked 2>/dev/null | grep -qi true
}

saved_delay() {
	if [[ -f "${DELAY_FILE}" ]]; then
		local d
		d="$(<"${DELAY_FILE}")"
		[[ -n "${d}" && "${d}" -gt 0 ]] && echo "${d}" && return 0
	fi
	echo 300
}

arm() {
	delay="${1:-300}"
	disarm
	echo "${delay}" >"${DELAY_FILE}"
	date +%s >"${ARM}"
	(
		sleep "${delay}"
		[[ -f "${ARM}" ]] || exit 0
		within_resume_grace && exit 0
		if is_locked; then
			release_audio_sleep_block
			loginctl suspend 2>/dev/null || systemctl suspend
		fi
	) &
	echo $! >"${PIDFILE}"
}

on_suspend() {
	if [[ -f "${ARM}" ]]; then
		echo 1 >"${WAS_ARMED}"
	else
		rm -f "${WAS_ARMED}"
	fi
	disarm
}

on_resume() {
	set_resume_grace "${RESUME_GRACE_SEC}"
	[[ -f "${WAS_ARMED}" ]] || return 0
	rm -f "${WAS_ARMED}"
	within_resume_grace || true
	if is_locked; then
		arm "$(saved_delay)"
	fi
}

case "${1:-}" in
arm) arm "${2:-300}" ;;
disarm) disarm ;;
on-suspend) on_suspend ;;
on-resume) on_resume ;;
*) echo "usage: $0 arm|disarm|on-suspend|on-resume [seconds]" >&2; exit 1 ;;
esac
