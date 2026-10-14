# Design: repo layout, installer, migration

## Layout
```
hypr/          Lua config (~/.config/hypr -> here)
shell/         Quickshell config (~/.config/quickshell/quantum-moon -> here)
quantum-moon/  engine (modes/, palettes/, scripts/)
bin/           user commands (~/.local/bin/qm-* -> here)
config/        quantum-moon/*.example, systemd/user/, uwsm/, wireplumber/, modprobe.d/, pacman/, sddm/, gtk/, kitty/,
               mimeapps.defaults, packages/{pacman,aur,optional}.txt
scripts/       install.sh, uninstall-caelestia.sh, cleanup-leftovers.sh, backup-baseline.sh, migrate-caelestia-state.sh,
               shell-dev.sh, hypr-verify.sh, system-steps.sh (everything needing sudo, printed for the user)
docs/          install.md, post-install.md, lua-config.md, shell-ipc.md, migrating-from-caelestia.md, dev/, screenshots/
extras/        middle-mouse-debounce/
```

## Paths
- Config: `~/.config/quantum-moon/{shell.json, monitors/<name>.json, vpn.json, git-watcher.json, services.json, root,
  backup-patterns.txt, generated/}`; `~/.config/quantum-moon/root` = absolute path of `<repo>/quantum-moon`.
- State: `~/.local/state/quantum-moon/{scheme.json, scheme.lua, current.json, state.json, random-walk.json, mpvpaper.pid,
  last-video.*, ship-log.json, git-watcher-*.json, launcher-item-overrides.json, launch-frequency.json, clip-pins.json,
  emoji-recent.json, nightlight.json, screens-runtime.json, main-monitor-fallback}`.
- Runtime markers: `$XDG_RUNTIME_DIR/quantum-moon-game-mode.active`, `quantum-moon-audio-playback.active`,
  `quantum-moon-resume-grace.until`, `quantum-moon-mpvpaper.sock`.
- Data: `~/.local/share/quantum-moon/launcher-icons/`.

## Units (graphical-session.target under UWSM)
quantum-moon-shell, hyprpaper (stock), hyprpolkitagent (stock), hyprsunset, hyprresume, quantum-moon-video,
quantum-moon-git-watcher, quantum-moon-suspend-resume-watch, quantum-moon-audio-inhibit, lan-mouse, llm-tray, cliphist (stock).
default.target: audio-analog-mic-setup, ydotool, shelly-notifications. timers: quantum-moon-backup.

## Keepers to mark explicit before removing caelestia-*/cachyos-hyprland-settings
hyprland slurp wl-clipboard brightnessctl capitaine-cursors noto-fonts noto-fonts-emoji xorg-xwayland
xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpicker cliphist inotify-tools app2unit trash-cli fish eza fastfetch
starship btop jq adw-gtk-theme papirus-icon-theme ttf-jetbrains-mono-nerd ddcutil networkmanager lm_sensors
ttf-material-symbols-variable power-profiles-daemon ttf-rubik-vf ttf-cascadia-code-nerd swappy libqalculate grim
gpu-screen-recorder dconf fuzzel python-pillow libnotify

## Removals (approved)
caelestia-meta caelestia-shell caelestia-cli (+ cascades libcava python-materialyoucolor foot qtengine-git);
quickshell-git -> quickshell; cachyos-hyprland-settings (+ cascades waybar mako wofi wlogout swaylock-effects-git
grimblast-git kvantum qt5ct hyprlauncher swaybg wob pamixer bemenu); wofi hyprlauncher waypaper hyprshot dolphin chromium
keyd polkit-gnome polkit-kde-agent cachyos-wallpapers vlc-gui-qt. Orphans: electron39 electron41 hyprwayland-scanner meson
extra-cmake-modules vulkan-headers mold llvm21-libs python-hatch python-hatch-vcs python-build python-installer
python-pkg_resources python-httpx autoconf-archive scdoc libliftoff libdispatch mbedtls svt-hevc mypaint-brushes1
gnome-desktop libayatana-indicator accounts-qml-module litehtml0.9.
KEEP: shelly, code, go, rust, lib32-*.
