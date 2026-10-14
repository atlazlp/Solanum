# Shared helpers for the quantum-moon engine (sourced; bash).
#
# qm_resolve_root [fallback]
#   Quantum Moon engine root during the Caelestia -> quantum-moon transition:
#     1. ~/.config/quantum-moon/root            (new installer)
#     2. ~/.config/caelestia/quantum-moon-root  (legacy, until cutover)
#     3. the fallback argument (callers pass their own repo-relative path)
#   A candidate is accepted only if it contains scripts/qm-apply.
qm_resolve_root() {
  local fallback="${1:-}" f root
  for f in "${XDG_CONFIG_HOME:-${HOME}/.config}/quantum-moon/root" "${HOME}/.config/caelestia/quantum-moon-root"; do
    [[ -f "${f}" ]] || continue
    root=""
    read -r root <"${f}" || true
    if [[ -n "${root}" && -f "${root}/scripts/qm-apply" ]]; then
      printf '%s\n' "${root}"
      return 0
    fi
  done
  [[ -n "${fallback}" ]] || return 1
  printf '%s\n' "${fallback}"
}

qm_state_dir() {
  printf '%s\n' "${XDG_STATE_HOME:-${HOME}/.local/state}/quantum-moon"
}

# Legacy Caelestia state dir, only while it still exists (mirrors are written there until cutover).
qm_legacy_state_dir() {
  local d="${XDG_STATE_HOME:-${HOME}/.local/state}/caelestia"
  [[ -d "${d}" ]] || return 1
  printf '%s\n' "${d}"
}
