# Migrating a Caelestia-era Quantum Moon install

Historical page for machines that ran the Caelestia-based version (tag `v0-caelestia-port-final`). New installs do not need it.

## Order

1. **Baseline**: `./scripts/backup-baseline.sh --tag pre-migration` (configs, state, units, package lists, hyprctl dumps, git bundle) to `/mnt/Backup/quantum-moon-baseline/`.
2. **Hyprland Lua** (side by side; Caelestia shell keeps running):
   ```sh
   ./scripts/hypr-verify.sh
   cp -L ~/.config/hypr/hyprpaper.conf ~/Projects/Quantum-Moon/hypr/hyprpaper.conf
   ln -sfn ~/Projects/Quantum-Moon/hypr ~/.config/hypr
   # then log out and back in: the config manager (hyprlang vs Lua) is chosen at startup, not on reload
   ```
   Rollback: `ln -sfn ~/.local/share/caelestia/hypr ~/.config/hypr` and log out/in. If a reload was issued by mistake (emergency binds only), relink the old dir and `hyprctl reload` restores the hyprlang session instantly. Checks are listed in `hypr/README.md`.
3. **Shell side by side**: `./scripts/shell-dev.sh` runs `qs -c quantum-moon` with dev flags (no notification server, no session lock, bar reserves no space). For a full test: `qs -c caelestia kill; qs -c quantum-moon`, then `caelestia shell -d` to go back.
4. **Cutover**: `./scripts/install.sh --migrate-caelestia --units` (copies state and config, never deletes), flip `hypr/lib/shell.lua` to the quantum-moon block, log out and in. Rollback: flip the block back, re-enable `caelestia-suspend-resume-watch.service`, restore the two autostart files from the baseline.
5. **UWSM**: `./scripts/system-steps.sh --run --sddm-uwsm`, log out. Rollback: restore `/etc/sddm.conf` and `caelestia-autologin.conf` from the baseline.
6. **Removals** (after a few stable days): `./scripts/uninstall-caelestia.sh` then `./scripts/cleanup-leftovers.sh`. Rollback: baseline tar + `yay -U` the saved `caelestia-meta` package + `git checkout v0-caelestia-port-final`.

## What moved where

| Before | After |
|---|---|
| `~/.config/caelestia/hypr-*.conf`, caelestia `hypr/hyprland/*.conf` | `hypr/*.lua` |
| `~/.config/caelestia/scripts/*` | Lua `hypr/features/*` or `hypr/scripts/*` |
| `~/.config/caelestia/shell.json`, `monitors/*/shell.json`, `bar-vpn.json`, `git-watcher.json` | `~/.config/quantum-moon/{shell.json, monitors/*.json, vpn.json, git-watcher.json}` |
| `~/.local/state/caelestia/*` | `~/.local/state/quantum-moon/*` |
| `~/.local/share/caelestia/launcher-icons` | `~/.local/share/quantum-moon/launcher-icons` |
| `caelestia shell ...` / `qs -c caelestia ipc call` | `qm-shell ...` / `qs -c quantum-moon ipc call` |
| `caelestia screenshot|record|clipboard|emoji` | `qm-screenshot`, `qm-record`, `qm-clip`, `qm-emoji` |
| `caelestia-*.service` | `quantum-moon-*.service` |
| `kitty-caelestia-qm.sock`, `colors-caelestia-qm.conf`, `CaelestiaQM.colors` | `kitty-quantum-moon.sock`, `colors-quantum-moon.conf`, `QuantumMoon.colors` |
