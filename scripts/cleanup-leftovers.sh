#!/usr/bin/env bash
# Trash stale config dirs of removed apps, remove approved orphan packages, clean package caches.
# Prints the plan; applies only with --yes.
#
#   scripts/cleanup-leftovers.sh [--dry-run] [--yes]
#
# Keep lists (config/packages/*.txt + shelly code go rust lib32-*) are diff-checked before every removal.
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run|-n) DRY=1 ;;
    --yes|-y) YES=1 ;;
    *) die "unknown option: $a" ;;
  esac
done
[[ "$YES" == "1" || "$DRY" == "1" ]] || { DRY=1; log "printing the plan (re-run with --yes to apply)"; }

# config dir -> owning package(s); trashed only when none of the packages is installed
declare -A OWNER=(
  [legcord]="legcord legcord-bin" [vesktop]="vesktop vesktop-bin" [spicetify]="spicetify-cli" [zed]="zed"
  [waybar]="waybar" [mako]="mako" [wofi]="wofi" [wlogout]="wlogout" [swaylock]="swaylock swaylock-effects-git"
  [hyprlauncher]="hyprlauncher" [waypaper]="waypaper" [foot]="foot" [Kvantum]="kvantum" [qt5ct]="qt5ct"
  [dolphinrc]="dolphin" [chromium]="chromium"
)
ORPHANS=(electron39 electron41 hyprwayland-scanner meson extra-cmake-modules vulkan-headers mold llvm21-libs
  python-hatch python-hatch-vcs python-build python-installer python-pkg_resources python-httpx autoconf-archive
  scdoc libliftoff libdispatch mbedtls svt-hevc mypaint-brushes1 gnome-desktop libayatana-indicator
  accounts-qml-module litehtml0.9)

trash() { # trash <path>
  if command -v trash-put >/dev/null 2>&1; then run trash-put "$1"
  else run mkdir -p "$QM_STATE/cleanup-trash/$STAMP"; run mv "$1" "$QM_STATE/cleanup-trash/$STAMP/"; fi
}

log "stale config directories"
for d in "${!OWNER[@]}"; do
  p="$CFG/$d"
  [[ -e "$p" ]] || continue
  installed=""
  for pk in ${OWNER[$d]}; do pacman -Qq "$pk" >/dev/null 2>&1 && installed="$pk"; done
  if [[ -n "$installed" ]]; then ok "keep $p ($installed installed)"; else trash "$p"; fi
done

log "orphan packages"
mapfile -t cur_orphans < <(pacman -Qdtq 2>/dev/null || true)
rm=()
for p in "${ORPHANS[@]}"; do
  pacman -Qq "$p" >/dev/null 2>&1 || continue
  if grep -qxF "$p" <<<"$(printf '%s\n' "${cur_orphans[@]}")"; then rm+=("$p"); else info "$p is no longer an orphan, keeping"; fi
done
if [[ ${#rm[@]} -gt 0 ]]; then
  mapfile -t would < <(pacman -Rnsp "${rm[@]}" 2>/dev/null | sed -E 's/-[^-]+-[^-]+$//' || true)
  assert_not_kept "${would[@]:-}" "${rm[@]}"
  run sudo pacman -Rns "${rm[@]}"
else ok "no listed orphans installed"; fi
left="$(pacman -Qdtq 2>/dev/null | grep -v '^lib32-' | grep -vxF -f <(keep_set) | grep -vxF -f <(printf '%s\n' "${rm[@]:-}") || true)"
[[ -n "$left" ]] && info "other orphans left alone (review by hand): $(tr '\n' ' ' <<<"$left")"

log "package caches"
if command -v paccache >/dev/null 2>&1; then
  run sudo paccache -rk2
  run sudo paccache -ruk0
  if systemctl is-enabled --quiet paccache.timer 2>/dev/null; then ok "paccache.timer enabled"; else run sudo systemctl enable --now paccache.timer; fi
else warn "paccache missing (pacman-contrib)"; fi
command -v yay >/dev/null 2>&1 && run yay -Sc --noconfirm
mapfile -t rootpkg < <(find "$HOME/.cache/yay" -maxdepth 2 -name pkg -user root 2>/dev/null || true)
if [[ ${#rootpkg[@]} -gt 0 ]]; then run sudo rm -rf "${rootpkg[@]}"; else ok "no root-owned yay pkg dirs"; fi
ok "cleanup done"
