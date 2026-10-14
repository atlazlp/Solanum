#!/usr/bin/env bash
# Phase 5: remove the Caelestia shell/cli/meta packages, the cachyos-hyprland-settings bundle and
# the approved leftovers, then the Caelestia files. Prints the plan first; nothing happens without --yes
# (or an interactive confirmation). Sudo steps are delegated to scripts/system-steps.sh --phase5.
#
#   scripts/uninstall-caelestia.sh [--dry-run] [--yes] [--skip-backup]
#
# Guards: refuses unless quantum-moon-shell.service is active and ~/.config/hypr resolves into this repo,
# and unless scripts/migrate-caelestia-state.sh --verify passes. Never removes shelly/code/go/rust/lib32-*.
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

SKIP_BACKUP=0
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run|-n) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --skip-backup) SKIP_BACKUP=1 ;;
    *) die "unknown option: $a" ;;
  esac
done
export DRY YES

log "guards"
if [[ "$DRY" == "0" ]]; then
  systemctl --user is-active --quiet quantum-moon-shell.service || die "quantum-moon-shell.service is not active; finish Phase 4 first"
  [[ "$(readlink -f "$CFG/hypr")" == "$REPO/hypr" ]] || die "~/.config/hypr does not resolve into $REPO/hypr"
  "$REPO/scripts/migrate-caelestia-state.sh" --verify || die "state migration incomplete"
else
  systemctl --user is-active --quiet quantum-moon-shell.service || warn "(dry) quantum-moon-shell.service is not active"
  [[ "$(readlink -f "$CFG/hypr")" == "$REPO/hypr" ]] || warn "(dry) ~/.config/hypr -> $(readlink -f "$CFG/hypr")"
  "$REPO/scripts/migrate-caelestia-state.sh" --verify || warn "(dry) state migration incomplete"
fi
ok "guards passed"

log "plan"
cat <<PLAN
  1. scripts/backup-baseline.sh --tag pre-uninstall
  2. qs -c caelestia kill; kill the old git-watcher; remove caelestia-* user units (+ mako mask, ollama unit)
  3. [sudo] mark keepers explicit; pacman -Rs caelestia-meta caelestia-shell caelestia-cli; pacman -S quickshell
  4. [sudo] pacman -Rs cachyos-hyprland-settings; pacman -Rns wofi hyprlauncher waypaper hyprshot dolphin chromium
            keyd polkit-gnome polkit-kde-agent cachyos-wallpapers vlc-gui-qt; rm /etc/keyd/*; rm caelestia-autologin.conf
  5. rm -rf ~/.config/quickshell/caelestia ~/.local/share/caelestia ~/.config/caelestia ~/.local/state/caelestia,
     kitty colors-caelestia-qm.conf, CaelestiaQM.colors, qt6ct CaelestiaQM.conf
  Keep lists: config/packages/{pacman,aur,optional}.txt + shelly code go rust lib32-* (checked before every pacman -R)
PLAN
"$REPO/scripts/system-steps.sh" --phase5 || true
confirm "Proceed with the uninstall?" || { info "aborted"; exit 0; }

log "1. baseline backup"
if [[ "$SKIP_BACKUP" == "1" ]]; then info "skipped (--skip-backup)"; else run "$REPO/scripts/backup-baseline.sh" --tag pre-uninstall; fi

log "2. stop the Caelestia shell and its helpers"
if pgrep -f 'qs -c caelestia' >/dev/null 2>&1 || pgrep -f 'quickshell.*caelestia' >/dev/null 2>&1; then run_sh "qs -c caelestia kill || true"; else ok "caelestia shell not running"; fi
if [[ -f "$STATE/caelestia/git-watcher.pid" ]]; then run_sh "kill \"\$(cat '$STATE/caelestia/git-watcher.pid')\" 2>/dev/null || true"; fi
run_sh "pkill -f '$CFG/caelestia/scripts/git-watcher.py' 2>/dev/null || true"
for u in caelestia-main-monitor-hotplug caelestia-suspend-resume-watch; do
  if systemctl --user cat "$u.service" >/dev/null 2>&1; then
    run_sh "systemctl --user disable --now $u.service 2>/dev/null || true"
    run rm -f "$CFG/systemd/user/$u.service"
  fi
done
if [[ -f "$CFG/systemd/user/ollama.service" ]]; then
  run_sh "systemctl --user disable --now ollama.service 2>/dev/null || true"
  run rm -f "$CFG/systemd/user/ollama.service"
fi
if [[ -L "$CFG/systemd/user/mako.service" ]]; then run rm -f "$CFG/systemd/user/mako.service"; fi
run systemctl --user daemon-reload

log "3-4. packages (sudo, via system-steps.sh --phase5)"
if [[ "$DRY" == "1" ]]; then "$REPO/scripts/system-steps.sh" --phase5; else "$REPO/scripts/system-steps.sh" --run --phase5; fi
if [[ "$DRY" == "0" ]] && pacman -Qq quickshell >/dev/null 2>&1; then run "$HOME/.local/bin/qm-restart-shell" || true; fi

log "5. files"
for d in "$CFG/quickshell/caelestia" "$SHARE/caelestia" "$CFG/caelestia" "$STATE/caelestia"; do
  [[ -e "$d" ]] && run rm -rf "$d"
done
for f in "$CFG/kitty/colors-caelestia-qm.conf" "$SHARE/color-schemes/CaelestiaQM.colors" "$CFG/qt6ct/colors/CaelestiaQM.conf" \
         "$CFG/autostart/de.feschber.LanMouse.desktop" "$CFG/autostart/llm-tray.desktop"; do
  [[ -e "$f" ]] && run rm -f "$f"
done
for f in "$CFG"/autostart/*.disabled.*; do [[ -e "$f" ]] && run rm -f "$f"; done
if [[ -f "$CFG/kitty/kitty.conf" ]] && grep -q 'colors-caelestia-qm' "$CFG/kitty/kitty.conf"; then
  run sed -i '/colors-caelestia-qm/d' "$CFG/kitty/kitty.conf"
fi
if [[ -f "$CFG/qt6ct/qt6ct.conf" ]] && grep -q 'CaelestiaQM' "$CFG/qt6ct/qt6ct.conf"; then
  info "qt6ct.conf still references CaelestiaQM; the next qm-apply rewrites it"
fi
ok "Caelestia removed. Check: pacman -Q caelestia-shell caelestia-cli cachyos-hyprland-settings (all missing), pacman -Qdt."
