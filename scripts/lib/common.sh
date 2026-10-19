#!/usr/bin/env bash
# Shared helpers for the Quantum Moon scripts. Source, do not execute.
#   DRY=1       print every command instead of running it
#   YES=1       skip confirmations
# shellcheck disable=SC2034
REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)"
DRY="${DRY:-0}"
YES="${YES:-0}"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
SHARE="${XDG_DATA_HOME:-$HOME/.local/share}"
QM_CFG="$CFG/solanum"
QM_STATE="$STATE/solanum"
QM_SHARE="$SHARE/solanum"
STAMP="$(date +%Y%m%d-%H%M%S)"

if [[ -t 1 ]]; then C_B=$'\e[1m'; C_D=$'\e[2m'; C_Y=$'\e[33m'; C_R=$'\e[31m'; C_G=$'\e[32m'; C_0=$'\e[0m'; else C_B=""; C_D=""; C_Y=""; C_R=""; C_G=""; C_0=""; fi

log()  { printf '%s==>%s %s\n' "$C_B" "$C_0" "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%sWARN%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
die()  { printf '%sERROR%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }
ok()   { printf '    %s[ok]%s %s\n' "$C_G" "$C_0" "$*"; }

# run <cmd...>: print the command; execute unless DRY=1.
run() {
  printf '    %s+%s %s\n' "$C_D" "$C_0" "$(printf '%q ' "$@")"
  [[ "$DRY" == "1" ]] && return 0
  "$@"
}
# run_sh "<shell snippet>": like run for pipelines/redirections.
run_sh() {
  printf '    %s+%s %s\n' "$C_D" "$C_0" "$1"
  [[ "$DRY" == "1" ]] && return 0
  bash -c "$1"
}
# write_file <path> <mode> : stdin -> file (atomic), only if content differs.
write_file() {
  local dst="$1" mode="${2:-644}" tmp
  tmp="$(mktemp)"; cat >"$tmp"
  if [[ -f "$dst" ]] && cmp -s "$tmp" "$dst"; then rm -f "$tmp"; ok "unchanged $dst"; return 0; fi
  printf '    %s+%s write %s (mode %s)\n' "$C_D" "$C_0" "$dst" "$mode"
  if [[ "$DRY" == "1" ]]; then rm -f "$tmp"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  install -m "$mode" "$tmp" "$dst"; rm -f "$tmp"
}
# copy_if_missing <src> <dst> [mode]
copy_if_missing() {
  local src="$1" dst="$2" mode="${3:-644}"
  [[ -e "$src" ]] || { warn "missing source $src"; return 0; }
  if [[ -e "$dst" ]]; then ok "kept existing $dst"; return 0; fi
  run install -D -m "$mode" "$src" "$dst"
}
# copy_sync <src> <dst> [mode]: copy when the content differs, backing up the old file.
copy_sync() {
  local src="$1" dst="$2" mode="${3:-644}"
  [[ -e "$src" ]] || { warn "missing source $src"; return 0; }
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then ok "unchanged $dst"; return 0; fi
  [[ -f "$dst" ]] && run cp -a "$dst" "$dst.bak.$STAMP"
  run install -D -m "$mode" "$src" "$dst"
}
# link <target> <linkpath>: idempotent symlink; real files/dirs are moved to <linkpath>.bak.<stamp>.
link() {
  local target="$1" path="$2"
  if [[ -L "$path" ]]; then
    if [[ "$(readlink -f "$path")" == "$(readlink -f "$target")" ]]; then ok "link $path -> $target"; return 0; fi
    info "relinking $path (was -> $(readlink "$path"))"
    run rm "$path"
  elif [[ -e "$path" ]]; then
    warn "$path exists and is not a symlink; moving to $path.bak.$STAMP"
    run mv "$path" "$path.bak.$STAMP"
  fi
  [[ -d "$(dirname "$path")" ]] || run mkdir -p "$(dirname "$path")"
  run ln -sfn "$target" "$path"
}
confirm() { # confirm "question"  -> 0 yes / 1 no
  [[ "$YES" == "1" ]] && return 0
  [[ "$DRY" == "1" ]] && return 0
  local a; read -rp "$1 [y/N] " a; [[ "$a" =~ ^[Yy]$ ]]
}
# pkg_list <file>: package names from a packages/*.txt file (comments stripped).
pkg_list() { sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | grep -v '^$' || true; }
# keep_set: every name that must never be removed (packages lists + hard keeps).
keep_set() {
  { pkg_list "$REPO/config/packages/pacman.txt"; pkg_list "$REPO/config/packages/aur.txt"; pkg_list "$REPO/config/packages/optional.txt"
    printf '%s\n' shelly code go rust; } | sort -u
}
# assert_not_kept <pkg...>: abort when any name is in the keep set or starts with lib32-.
assert_not_kept() {
  local bad=() p
  local keeps; keeps="$(keep_set)"
  for p in "$@"; do
    [[ "$p" == lib32-* ]] && bad+=("$p")
    grep -qxF "$p" <<<"$keeps" && bad+=("$p")
  done
  if [[ ${#bad[@]} -gt 0 ]]; then die "refusing: removal set contains keepers: ${bad[*]}"; fi
}
