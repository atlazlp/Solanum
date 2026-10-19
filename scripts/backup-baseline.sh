#!/usr/bin/env bash
# Archive the live desktop state (configs, state, units, package lists, hyprctl dumps)
# plus a git bundle of this repo. Used before every destructive migration step.
#   backup-baseline.sh [--tag NAME] [--out DIR]
# Default output: /mnt/Backup/solanum-baseline/<stamp>[-NAME]/ if /mnt/Backup is
# mounted, else <repo>/backup/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG=""; OUT_ROOT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="-$2"; shift 2 ;;
    --out) OUT_ROOT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
if [[ -z "$OUT_ROOT" ]]; then
  if mountpoint -q /mnt/Backup 2>/dev/null || [[ -d /mnt/Backup ]]; then OUT_ROOT=/mnt/Backup/solanum-baseline; else OUT_ROOT="$ROOT/backup"; fi
fi
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$OUT_ROOT/$STAMP$TAG"
mkdir -p "$OUT"/{config,state,share,etc,dumps}
echo "==> $OUT"

copy() { # copy <src> <dst-subdir>
  local src="$1" dst="$OUT/$2"
  [[ -e "$src" ]] || return 0
  mkdir -p "$dst"
  cp -aL --parents "$src" "$dst" 2>/dev/null || cp -a "$src" "$dst" 2>/dev/null || true
}

for d in caelestia quickshell solanum kitty qt6ct qt5ct gtk-3.0 gtk-4.0 systemd/user autostart uwsm mimeapps.list; do
  copy "$HOME/.config/$d" config
done
# resolved hypr tree (today a symlink into the caelestia checkout)
if [[ -e "$HOME/.config/hypr" ]]; then
  mkdir -p "$OUT/config/hypr-resolved"
  cp -aL "$HOME/.config/hypr/." "$OUT/config/hypr-resolved/" 2>/dev/null || true
  readlink -f "$HOME/.config/hypr" > "$OUT/config/hypr-symlink-target.txt" || true
fi
for d in caelestia solanum; do copy "$HOME/.local/state/$d" state; done
copy "$HOME/.local/share/caelestia/launcher-icons" share
copy "$HOME/.local/share/solanum" share
copy "$HOME/.local/share/color-schemes" share
[[ -f "$HOME/.local/share/caelestia/caelestia-meta-r183.cf94e7f-1-any.pkg.tar.zst" ]] && cp -a "$HOME/.local/share/caelestia/"caelestia-meta-*.pkg.tar.zst "$OUT/share/" || true
for f in /etc/sddm.conf /etc/sddm.conf.d /etc/keyd /etc/modprobe.d /etc/pacman.d/hooks /etc/systemd/system/middle-mouse-debounce.service /etc/systemd/system/middle-mouse-debounce.service.d; do
  [[ -e "$f" ]] && cp -a "$f" "$OUT/etc/" 2>/dev/null || true
done

pacman -Qqe > "$OUT/dumps/pacman-explicit.txt" 2>/dev/null || true
pacman -Qqm > "$OUT/dumps/pacman-foreign.txt" 2>/dev/null || true
pacman -Qdt > "$OUT/dumps/pacman-orphans.txt" 2>/dev/null || true
pacman -Q  > "$OUT/dumps/pacman-all.txt" 2>/dev/null || true
systemctl --user list-unit-files > "$OUT/dumps/systemd-user-unit-files.txt" 2>/dev/null || true
systemctl --user list-units --all > "$OUT/dumps/systemd-user-units.txt" 2>/dev/null || true
if command -v hyprctl >/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  hyprctl binds -j > "$OUT/dumps/hyprctl-binds.json" 2>/dev/null || true
  hyprctl monitors -j > "$OUT/dumps/hyprctl-monitors.json" 2>/dev/null || true
  hyprctl globalshortcuts > "$OUT/dumps/hyprctl-globalshortcuts.txt" 2>/dev/null || true
  hyprctl version > "$OUT/dumps/hyprctl-version.txt" 2>/dev/null || true
fi
for c in caelestia solanum; do qs -c "$c" ipc show > "$OUT/dumps/qs-$c-ipc.txt" 2>/dev/null || true; done
xdg-mime query default inode/directory > "$OUT/dumps/mime-inode-directory.txt" 2>/dev/null || true

{
  echo "created=$STAMP"
  echo "repo=$ROOT"
  echo "git_commit=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "hypr_config_symlink=$(readlink "$HOME/.config/hypr" 2>/dev/null || echo none)"
} > "$OUT/REVISION.txt"
git -C "$ROOT" bundle create "$OUT/repo-all.bundle" --all >/dev/null 2>&1 || true

du -sh "$OUT" | awk '{print "==> done, size " $1}'
