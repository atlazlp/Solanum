#!/usr/bin/env bash
# Quantum Moon installer. Idempotent; every phase can be re-run.
#
#   scripts/install.sh [options]
#
#   --dry-run            print every command, change nothing
#   --full               everything: packages, --link-hypr, --units, --migrate-caelestia (if
#                        ~/.config/caelestia exists), --sddm-uwsm, system steps
#   --quick              user-level refresh only: symlinks, configs, env (= --no-packages --no-system)
#   --no-packages        skip the package phase
#   --no-system          skip the system (sudo) phase and do not print it
#   --link-hypr          point ~/.config/hypr at <repo>/hypr (the Hyprland switch; off by default)
#   --units              install + enable the user units (default with --full)
#   --migrate-caelestia  copy Caelestia state/config into the solanum paths (never moves)
#   --sddm-uwsm          include the SDDM -> hyprland-uwsm switch in the system steps
#   --force-mime         overwrite existing MIME defaults with config/mimeapps.defaults
#   --yes                run the sudo steps (scripts/system-steps.sh --run) instead of printing them
#
# Phases: preflight -> packages -> symlinks -> config seeding -> MIME/GTK/kitty/uwsm env -> units
#         -> system steps (printed, or run with --yes) -> state migration -> finish.
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

PACKAGES=1; SYSTEM=1; LINK_HYPR=0; UNITS=0; MIGRATE=0; SDDM=0; FORCE_MIME=0; FULL=0
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --dry-run|-n) DRY=1 ;;
    --full) FULL=1; LINK_HYPR=1; UNITS=1; SDDM=1; [[ -d "$CFG/caelestia" ]] && MIGRATE=1 ;;
    --quick) PACKAGES=0; SYSTEM=0 ;;
    --no-packages) PACKAGES=0 ;;
    --no-system) SYSTEM=0 ;;
    --link-hypr) LINK_HYPR=1 ;;
    --units) UNITS=1 ;;
    --migrate-caelestia) MIGRATE=1 ;;
    --sddm-uwsm) SDDM=1 ;;
    --force-mime) FORCE_MIME=1 ;;
    --yes|-y) YES=1 ;;
    *) die "unknown option: $a (see --help)" ;;
  esac
done
export DRY YES
[[ "$DRY" == "1" ]] && log "DRY RUN: nothing will be changed"

# ---------------------------------------------------------------- preflight
log "preflight ($REPO)"
[[ -d "$REPO/bin" && -d "$REPO/config" && -d "$REPO/solanum" ]] || die "not a Quantum-Moon checkout: $REPO"
for t in jq systemctl install ln; do command -v "$t" >/dev/null 2>&1 || die "missing tool: $t"; done
[[ -d "$REPO/hypr" ]] || warn "$REPO/hypr is missing (Lua config not landed yet); --link-hypr will be skipped"
[[ -d "$REPO/shell" ]] || warn "$REPO/shell is missing (shell not landed yet); the quickshell symlink will dangle"
if [[ -L "$CFG/hypr" ]]; then info "~/.config/hypr -> $(readlink "$CFG/hypr")"; fi
if [[ "$LINK_HYPR" == "1" && ! -d "$REPO/hypr" ]]; then LINK_HYPR=0; fi
if [[ "$FULL" == "1" && "$MIGRATE" == "0" ]]; then info "no ~/.config/caelestia: migration skipped"; fi
SYS_FLAGS=()

# ---------------------------------------------------------------- packages (via system-steps.sh, needs sudo)
if [[ "$PACKAGES" == "1" ]]; then
  log "packages (config/packages/pacman.txt + aur.txt)"
  missing=()
  while read -r p; do
    [[ -z "$p" ]] && continue
    if pacman -Qq "$p" >/dev/null 2>&1; then continue; fi
    if pacman -Qq "${p}-git" >/dev/null 2>&1; then warn "$p: ${p}-git is installed instead (replaced in Phase 5)"; continue; fi
    missing+=("$p")
  done < <(pkg_list "$REPO/config/packages/pacman.txt"; pkg_list "$REPO/config/packages/aur.txt")
  if [[ ${#missing[@]} -eq 0 ]]; then ok "all packages present"; else info "to install: ${missing[*]}"; SYS_FLAGS+=(--packages); fi
else
  log "packages: skipped"
fi

# ---------------------------------------------------------------- symlinks
log "symlinks"
link "$REPO/shell" "$CFG/quickshell/solanum"
for f in "$REPO"/bin/qm-*; do
  link "$f" "$HOME/.local/bin/$(basename "$f")"
done
printf '%s\n' "$REPO/solanum" | write_file "$QM_CFG/root" 644
if [[ "$LINK_HYPR" == "1" ]]; then
  link "$REPO/hypr" "$CFG/hypr"
else
  info "~/.config/hypr left alone (pass --link-hypr to switch to the Lua config)"
fi
if [[ -L "$CFG/caelestia/quantum-moon-root" || -f "$CFG/caelestia/quantum-moon-root" ]]; then
  ok "legacy ~/.config/caelestia/quantum-moon-root kept (qm-apply still reads it until the engine is updated)"
fi

# ---------------------------------------------------------------- config seeding
log "config seeding (~/.config/solanum)"
run mkdir -p "$QM_CFG/monitors" "$QM_CFG/generated" "$QM_STATE" "$QM_SHARE/launcher-icons"
for ex in "$REPO"/config/solanum/*.example; do
  name="$(basename "$ex" .example)"
  mode=644
  case "$name" in git-watcher.json|vpn.json|services.json) mode=600 ;; esac
  # Secrets with a Caelestia-era counterpart are migrated (copied) by migrate-caelestia-state.sh;
  # seeding the empty example first would make the migration skip the real file.
  case "$name" in
    git-watcher.json) [[ -f "$HOME/.config/caelestia/git-watcher.json" && ! -f "$QM_CFG/$name" ]] && { ok "skip seeding $name (legacy config will be migrated)"; continue; } ;;
    vpn.json)         [[ -f "$HOME/.config/caelestia/bar-vpn.json"     && ! -f "$QM_CFG/$name" ]] && { ok "skip seeding $name (legacy config will be migrated)"; continue; } ;;
  esac
  copy_if_missing "$ex" "$QM_CFG/$name" "$mode"
done
copy_if_missing "$REPO/config/solanum/nautilus-sidebar-extra" "$QM_CFG/nautilus-sidebar-extra"
copy_if_missing "$REPO/config/solanum/nautilus-drive-icons" "$QM_CFG/nautilus-drive-icons"
for f in "$REPO"/config/wireplumber/wireplumber.conf.d/*.conf; do
  copy_sync "$f" "$CFG/wireplumber/wireplumber.conf.d/$(basename "$f")"
done
# secrets stay private even when they pre-existed
for s in git-watcher.json vpn.json; do
  [[ -f "$QM_CFG/$s" ]] && run chmod 600 "$QM_CFG/$s"
done

# ---------------------------------------------------------------- MIME / GTK / kitty / uwsm env
log "MIME defaults"
while IFS='=' read -r mime desktop; do
  [[ -z "$mime" || "$mime" == \#* ]] && continue
  cur="$(xdg-mime query default "$mime" 2>/dev/null || true)"
  if [[ "$cur" == "$desktop" ]]; then ok "$mime = $desktop"
  elif [[ -n "$cur" && "$FORCE_MIME" == "0" ]]; then info "$mime stays $cur (pass --force-mime for $desktop)"
  else run xdg-mime default "$desktop" "$mime"; fi
done < "$REPO/config/mimeapps.defaults"

log "GTK settings"
copy_if_missing "$REPO/config/gtk/gtk-3.0.settings.ini" "$CFG/gtk-3.0/settings.ini"
copy_if_missing "$REPO/config/gtk/gtk-4.0.settings.ini" "$CFG/gtk-4.0/settings.ini"

log "kitty integration"
copy_sync "$REPO/config/kitty/solanum.conf" "$CFG/kitty/solanum.conf"
kc="$CFG/kitty/kitty.conf"
if [[ -f "$kc" ]] && grep -q 'kitty-caelestia-qm.sock\|colors-caelestia-qm.conf' "$kc"; then
  info "dropping legacy caelestia lines from kitty.conf (migrate-caelestia-state.sh copies the colour file)"
  run_sh "sed -i -e '/^# solanum: listen_on + allow_remote_control so qm-apply can run$/d' -e '/^listen_on unix:\${XDG_RUNTIME_DIR}\/kitty-caelestia-qm.sock$/d' -e '/^include colors-caelestia-qm.conf$/d' '$kc'"
fi
if [[ -f "$kc" ]] && grep -q '^# BEGIN solanum$' "$kc"; then
  ok "kitty.conf already includes solanum.conf"
else
  run_sh "mkdir -p '$CFG/kitty' && { printf '%s\n' '# BEGIN solanum' 'include solanum.conf' '# END solanum'; [[ -f '$kc' ]] && cat '$kc'; } > '$kc.tmp' && mv '$kc.tmp' '$kc'"
fi
[[ -f "$CFG/kitty/colors-solanum.conf" ]] || { [[ "$DRY" == "1" ]] || : > "$CFG/kitty/colors-solanum.conf"; info "created empty colors-solanum.conf (filled by qm-apply)"; }
# Drop settings now owned by solanum.conf (kitty warns on duplicate includes / options)
if [[ -f "$kc" ]]; then
  run_sh "sed -i \
    -e '/^# solanum: listen_on + allow_remote_control so qm-apply can run$/d' \
    -e '/^# kitten @ --to … set-colors without a controlling TTY\.$/d' \
    -e '/^allow_remote_control socket$/d' \
    -e '/^listen_on unix:\${XDG_RUNTIME_DIR}\/kitty-solanum\.sock$/d' \
    -e '/^listen_on unix:\${XDG_RUNTIME_DIR}\/kitty-caelestia-qm\.sock$/d' \
    -e '/^include colors-solanum\.conf$/d' \
    -e '/^include colors-caelestia-qm\.conf$/d' \
    '$kc'"
fi

log "Firefox Pywalfox host (optional; needs the Pywalfox add-on)"
if [[ -x "$REPO/solanum/scripts/qm-pywalfox-host" ]]; then
  run "$REPO/solanum/scripts/qm-pywalfox-host" install
else
  info "qm-pywalfox-host missing or not executable — skipped"
fi

log "uwsm environment"
copy_sync "$REPO/config/uwsm/env-hyprland" "$CFG/uwsm/env-hyprland"

# ---------------------------------------------------------------- units
if [[ "$UNITS" == "1" ]]; then
  log "systemd user units"
  for u in "$REPO"/config/systemd/user/*.service "$REPO"/config/systemd/user/*.timer; do
    copy_sync "$u" "$CFG/systemd/user/$(basename "$u")"
  done
  run systemctl --user daemon-reload
  # graphical-session.target units: enable only (they start on the next UWSM login)
  for u in solanum-shell solanum-video solanum-git-watcher solanum-suspend-resume-watch \
           solanum-audio-inhibit hyprsunset hyprresume lan-mouse llm-tray hyprpaper hyprpolkitagent cliphist; do
    if [[ -f "$REPO/config/systemd/user/$u.service" ]] || systemctl --user cat "$u.service" >/dev/null 2>&1; then
      if systemctl --user is-enabled --quiet "$u.service" 2>/dev/null; then ok "$u.service enabled"; else run systemctl --user enable "$u.service"; fi
    else warn "$u.service not found (package missing?)"; fi
  done
  if systemctl --user is-enabled --quiet audio-analog-mic-setup.service 2>/dev/null; then ok "audio-analog-mic-setup.service enabled"; else run systemctl --user enable audio-analog-mic-setup.service; fi
  if systemctl --user is-enabled --quiet solanum-backup.timer 2>/dev/null; then ok "solanum-backup.timer enabled"; else run systemctl --user enable --now solanum-backup.timer; fi
  if [[ "$MIGRATE" == "1" ]]; then
    for u in caelestia-main-monitor-hotplug caelestia-suspend-resume-watch; do
      if systemctl --user is-enabled --quiet "$u.service" 2>/dev/null; then run systemctl --user disable "$u.service"; info "$u.service disabled (still running until logout)"; fi
    done
    for d in de.feschber.LanMouse llm-tray; do
      [[ -f "$CFG/autostart/$d.desktop" ]] && run mv "$CFG/autostart/$d.desktop" "$CFG/autostart/$d.desktop.disabled.$STAMP"
    done
  fi
  if ! systemctl --user is-active --quiet graphical-session.target 2>/dev/null; then
    info "graphical-session.target is inactive (plain Hyprland session): units start after the switch to hyprland-uwsm"
  fi
else
  log "units: skipped (pass --units or --full)"
fi

# ---------------------------------------------------------------- system steps (sudo)
if [[ "$SYSTEM" == "1" ]]; then
  SYS_FLAGS+=(--system)
  [[ "$SDDM" == "1" ]] && SYS_FLAGS+=(--sddm-uwsm)
  log "system steps (sudo): ${SYS_FLAGS[*]}"
  if [[ "$YES" == "1" && "$DRY" == "0" ]]; then
    "$REPO/scripts/system-steps.sh" --run "${SYS_FLAGS[@]}"
  else
    "$REPO/scripts/system-steps.sh" "${SYS_FLAGS[@]}"
    info ""
    info "Run them with:  $REPO/scripts/system-steps.sh --run ${SYS_FLAGS[*]}"
  fi
else
  log "system steps: skipped"
fi

# ---------------------------------------------------------------- state migration
if [[ "$MIGRATE" == "1" ]]; then
  log "migrating Caelestia state"
  margs=(); [[ "$DRY" == "1" ]] && margs+=(--dry-run)
  "$REPO/scripts/migrate-caelestia-state.sh" "${margs[@]}"
fi

# ---------------------------------------------------------------- finish
log "finish"
if [[ "$LINK_HYPR" == "1" ]] && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  run hyprctl reload
fi
if [[ -d "$REPO/.git" ]] && command -v git-lfs >/dev/null 2>&1; then
  if ! find "$REPO/solanum/modes" -name center.mp4 -size +1M 2>/dev/null | grep -q .; then
    info "center.mp4 videos are LFS pointers: run qm-fetch-videos when you want them"
  fi
fi
{
  echo "$(date -Is) install.sh dry=$DRY full=$FULL link_hypr=$LINK_HYPR units=$UNITS migrate=$MIGRATE sddm=$SDDM system=$SYSTEM packages=$PACKAGES"
} | { if [[ "$DRY" == "1" ]]; then cat >/dev/null; else mkdir -p "$QM_STATE" && cat >>"$QM_STATE/install.log"; fi; }
ok "done. Next: log out and back in (or 'qm-restart-shell' for the shell only)."
