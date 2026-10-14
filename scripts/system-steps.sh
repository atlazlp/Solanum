#!/usr/bin/env bash
# Every system-level (sudo) step of the Quantum Moon setup, in order, each idempotent.
# Prints the commands by default; --run executes them through sudo (you will be asked for
# your password; no passwordless sudo is required).
#
#   scripts/system-steps.sh [--run] [--packages] [--system] [--sddm-uwsm] [--phase5] [--all]
#
#   --packages   pacman -Syu, install config/packages/pacman.txt, yay config/packages/aur.txt,
#                mark everything in those lists (and the keepers) explicit
#   --system     pacman pkglist hook, modprobe ALC897 quirk, paccache.timer
#   --sddm-uwsm  write /etc/sddm.conf.d/quantum-moon-autologin.conf, remove caelestia-autologin.conf,
#                sed /etc/sddm.conf Session=hyprland -> hyprland-uwsm
#   --phase5     the approved removals (Caelestia packages, cachyos-hyprland-settings bundle, leftovers,
#                keyd config); refuses when the removal set touches a keeper
#   --all        --packages --system --sddm-uwsm
#   --run        execute instead of print
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/lib/common.sh"

RUN=0; P=0; S=0; SD=0; P5=0
for a in "$@"; do
  case "$a" in
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --run) RUN=1 ;;
    --packages) P=1 ;;
    --system) S=1 ;;
    --sddm-uwsm) SD=1 ;;
    --phase5) P5=1 ;;
    --all) P=1; S=1; SD=1 ;;
    *) die "unknown option: $a" ;;
  esac
done
[[ $((P+S+SD+P5)) -gt 0 ]] || { P=1; S=1; SD=1; }
if [[ "$RUN" == "0" ]]; then DRY=1; log "printing system steps (add --run to execute with sudo)"; else DRY=0; fi

sudo_run() { run sudo "$@"; }
sudo_sh()  { run_sh "sudo bash -c '$1'"; }

# ------------------------------------------------------------------ packages
if [[ "$P" == "1" ]]; then
  log "packages"
  sudo_run pacman -Syu --needed
  mapfile -t repo_pkgs < <(pkg_list "$REPO/config/packages/pacman.txt")
  mapfile -t aur_pkgs < <(pkg_list "$REPO/config/packages/aur.txt")
  need=()
  for p in "${repo_pkgs[@]}"; do
    pacman -Qq "$p" >/dev/null 2>&1 && continue
    if pacman -Qq "${p}-git" >/dev/null 2>&1; then warn "$p: ${p}-git installed, skipping (handled by --phase5)"; continue; fi
    need+=("$p")
  done
  if [[ ${#need[@]} -gt 0 ]]; then sudo_run pacman -S --needed --asexplicit "${need[@]}"; else ok "repo packages present"; fi
  need=()
  for p in "${aur_pkgs[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || need+=("$p"); done
  if [[ ${#need[@]} -gt 0 ]]; then
    command -v yay >/dev/null 2>&1 || die "yay is required for AUR packages: ${need[*]}"
    run yay -S --needed --asexplicit "${need[@]}"   # yay calls sudo itself
  else ok "AUR packages present"; fi
  # mark keepers explicit so later removals never cascade into them
  mark=()
  while read -r p; do [[ -n "$p" ]] && pacman -Qq "$p" >/dev/null 2>&1 && mark+=("$p"); done < <(keep_set)
  deps=()
  for p in "${mark[@]}"; do pacman -Qdq "$p" >/dev/null 2>&1 && deps+=("$p"); done
  if [[ ${#deps[@]} -gt 0 ]]; then sudo_run pacman -D --asexplicit "${deps[@]}"; else ok "keepers already explicit"; fi
fi

# ------------------------------------------------------------------ system files
if [[ "$S" == "1" ]]; then
  log "pacman pkglist hook"
  hook=/etc/pacman.d/hooks/50-quantum-moon-pkglist.hook
  if cmp -s "$REPO/config/pacman/50-quantum-moon-pkglist.hook" "$hook" 2>/dev/null; then ok "$hook up to date"
  else sudo_run install -D -m644 "$REPO/config/pacman/50-quantum-moon-pkglist.hook" "$hook"; fi
  sudo_sh 'mkdir -p /var/lib/quantum-moon && pacman -Qqe > /var/lib/quantum-moon/pkglist-explicit.txt && pacman -Qq > /var/lib/quantum-moon/pkglist-all.txt; pacman -Qqm > /var/lib/quantum-moon/pkglist-foreign.txt; true'

  log "modprobe: ALC897 headset quirk"
  mp=/etc/modprobe.d/alsa-realtek-alc897-headset.conf
  if cmp -s "$REPO/config/modprobe.d/alsa-realtek-alc897-headset.conf" "$mp" 2>/dev/null; then ok "$mp up to date"
  else sudo_run install -D -m644 "$REPO/config/modprobe.d/alsa-realtek-alc897-headset.conf" "$mp"; info "(takes effect after reboot)"; fi

  log "paccache.timer"
  if pacman -Qq pacman-contrib >/dev/null 2>&1; then
    if systemctl is-enabled --quiet paccache.timer 2>/dev/null; then ok "paccache.timer enabled"; else sudo_run systemctl enable --now paccache.timer; fi
  else warn "pacman-contrib not installed; paccache.timer skipped"; fi
fi

# ------------------------------------------------------------------ SDDM -> UWSM
if [[ "$SD" == "1" ]]; then
  log "SDDM autologin -> hyprland-uwsm"
  [[ -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] || warn "hyprland-uwsm.desktop missing: install uwsm first"
  src="$REPO/config/sddm/quantum-moon-autologin.conf.example"
  dst=/etc/sddm.conf.d/quantum-moon-autologin.conf
  tmp="$(mktemp -t quantum-moon-autologin.XXXXXX)"; sed -e "s/^User=.*/User=$USER/" "$src" > "$tmp"
  if cmp -s "$tmp" "$dst" 2>/dev/null; then ok "$dst up to date"; else sudo_run install -D -m644 "$tmp" "$dst"; fi
  rm -f "$tmp"
  [[ -f /etc/sddm.conf.d/caelestia-autologin.conf ]] && sudo_run rm -f /etc/sddm.conf.d/caelestia-autologin.conf
  if [[ -f /etc/sddm.conf ]] && grep -Eq '^Session=hyprland(\.desktop)?$' /etc/sddm.conf; then
    sudo_run sed -i -E 's/^Session=hyprland(\.desktop)?$/Session=hyprland-uwsm/' /etc/sddm.conf
  else ok "/etc/sddm.conf has no plain hyprland session line"; fi
fi

# ------------------------------------------------------------------ Phase 5 removals
if [[ "$P5" == "1" ]]; then
  log "phase 5: removals"
  keepers=(hyprland slurp wl-clipboard brightnessctl capitaine-cursors noto-fonts noto-fonts-emoji xorg-xwayland
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpicker cliphist inotify-tools app2unit trash-cli fish eza
    fastfetch starship btop jq adw-gtk-theme papirus-icon-theme ttf-jetbrains-mono-nerd ddcutil networkmanager
    lm_sensors ttf-material-symbols-variable power-profiles-daemon ttf-rubik-vf ttf-cascadia-code-nerd swappy
    libqalculate grim gpu-screen-recorder dconf fuzzel python-pillow libnotify shelly code go rust)
  deps=()
  for p in "${keepers[@]}"; do pacman -Qdq "$p" >/dev/null 2>&1 && deps+=("$p"); done
  if [[ ${#deps[@]} -gt 0 ]]; then sudo_run pacman -D --asexplicit "${deps[@]}"; else ok "keepers already explicit"; fi

  remove_group() { # remove_group <pacman flags> <pkgs...>
    local flags="$1"; shift
    local present=() p
    for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 && present+=("$p"); done
    [[ ${#present[@]} -gt 0 ]] || { ok "already gone: $*"; return 0; }
    mapfile -t would < <(pacman "-${flags}p" "${present[@]}" 2>/dev/null | sed -E 's/-[^-]+-[^-]+$//' || true)
    if [[ "$DRY" == "1" && ${#deps[@]} -gt 0 ]]; then
      # preview: keepers are marked explicit first in the real run, so drop them from the cascade
      mapfile -t would < <(printf '%s\n' "${would[@]}" | grep -vxF -f <(printf '%s\n' "${deps[@]}") || true)
    fi
    [[ ${#would[@]} -gt 0 ]] && assert_not_kept "${would[@]}"
    info "removal set: ${would[*]:-${present[*]}}"
    sudo_run pacman "-$flags" "${present[@]}"
  }
  remove_group Rs caelestia-meta caelestia-shell caelestia-cli
  if pacman -Qq quickshell-git >/dev/null 2>&1; then
    sudo_run pacman -S --asexplicit quickshell   # replaces quickshell-git (conflict prompt)
    info "restart the shell afterwards: qm-restart-shell"
  else ok "quickshell already from the repo"; fi
  remove_group Rs cachyos-hyprland-settings
  remove_group Rns wofi hyprlauncher waypaper hyprshot dolphin chromium keyd polkit-gnome polkit-kde-agent cachyos-wallpapers vlc-gui-qt
  if [[ -d /etc/keyd ]] && [[ -n "$(ls -A /etc/keyd 2>/dev/null)" ]]; then sudo_sh 'rm -rf /etc/keyd/*'; else ok "/etc/keyd empty"; fi
  [[ -f /etc/sddm.conf.d/caelestia-autologin.conf ]] && sudo_run rm -f /etc/sddm.conf.d/caelestia-autologin.conf
  ok "phase 5 system steps done"
fi
