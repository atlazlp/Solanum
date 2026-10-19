#!/usr/bin/env bash
set -eu

state="${XDG_STATE_HOME:-$HOME/.local/state}/solanum/state.json"
if [[ -f "${state}" ]] && command -v jq >/dev/null 2>&1; then
	if jq -e '.planetLocked == true' "${state}" >/dev/null 2>&1; then
		exit 0
	fi
fi

# Quantum Moon root: ~/.config/solanum/root, then ~/.config/caelestia/quantum-moon-root (legacy), else <repo>/solanum.
QM=""
for root_file in "${HOME}/.config/solanum/root" "${HOME}/.config/caelestia/quantum-moon-root"; do
	[[ -f "${root_file}" ]] || continue
	read -r QM <"${root_file}" || true
	[[ -n "${QM}" ]] && break
done
if [[ -z "${QM}" ]]; then
	QM="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../../solanum" 2>/dev/null && pwd)" || exit 0
fi
[[ -n "${QM}" && -x "${QM}/scripts/qm-random" ]] || exit 0
exec "${QM}/scripts/qm-random"
