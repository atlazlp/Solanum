#!/usr/bin/env bash
set -eu

state="${XDG_STATE_HOME:-$HOME/.local/state}/quantum-moon/state.json"
if [[ -f "${state}" ]] && command -v jq >/dev/null 2>&1; then
	if jq -e '.planetLocked == true' "${state}" >/dev/null 2>&1; then
		exit 0
	fi
fi

# Quantum Moon root: ~/.config/quantum-moon/root, then ~/.config/caelestia/quantum-moon-root (legacy), else <repo>/quantum-moon.
QM=""
for root_file in "${HOME}/.config/quantum-moon/root" "${HOME}/.config/caelestia/quantum-moon-root"; do
	[[ -f "${root_file}" ]] || continue
	read -r QM <"${root_file}" || true
	[[ -n "${QM}" ]] && break
done
if [[ -z "${QM}" ]]; then
	QM="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../quantum-moon" 2>/dev/null && pwd)" || exit 0
fi
[[ -n "${QM}" && -x "${QM}/scripts/qm-random" ]] || exit 0
exec "${QM}/scripts/qm-random"
