# Installing Quantum Moon

Target: Arch Linux / CachyOS with Hyprland 0.56 or newer (the config is Lua; hyprlang `.conf` is not used).

## 1. Prerequisites

- `git`, `git-lfs`, `yay` (or another AUR helper; the scripts call `yay`).
- A display manager that can start the `Hyprland (uwsm)` session (SDDM is what the scripts configure).
- Three monitors are what the defaults describe (left portrait HDMI-A-1, centre DP-2, right DP-3). One or two monitors work: see post-install.

## 2. Clone

```sh
GIT_LFS_SKIP_SMUDGE=1 git clone https://github.com/atlazlp/Quantum-Moon.git ~/Projects/Quantum-Moon
```

`GIT_LFS_SKIP_SMUDGE=1` skips the six centre-monitor videos (about 110 MB each). GitHub's free LFS bandwidth is 1 GB per month, so two fresh clones with videos exhaust it. Fetch them later with `qm-fetch-videos`; without them the centre monitor shows the static `slot-1.png`.

The repo can live anywhere under `$HOME`; the installer records its location in `~/.config/quantum-moon/root`.

## 3. Read the plan, then run it

```sh
cd ~/Projects/Quantum-Moon
./scripts/install.sh --dry-run --full
```

`install.sh` is idempotent and user-level. `--full` does: package check (prints what `system-steps.sh` will install), symlinks (`~/.config/hypr -> hypr/`, `~/.config/quickshell/quantum-moon -> shell/`, `~/.local/bin/qm-* -> bin/`), config seeding from `config/quantum-moon/*.example` (never overwrites an existing file; secrets get mode 600), MIME default for folders (Nautilus), GTK `settings.ini`, kitty include block, uwsm env, systemd user units (enabled, started on the next login), and the backup timer.

```sh
./scripts/install.sh --full
./scripts/system-steps.sh            # prints the sudo steps
./scripts/system-steps.sh --run --all
```

`system-steps.sh` is the only script that needs `sudo`: `pacman -Syu`, installs `config/packages/pacman.txt` and the AUR list, marks the keep list explicit, installs the pacman package-list hook and modprobe snippets, enables `paccache.timer`, and switches SDDM autologin to `hyprland-uwsm`.

## 4. First login

Log out, choose **Hyprland (uwsm)** (autologin does it after `system-steps.sh --sddm-uwsm`). Check:

```sh
systemctl --user is-active graphical-session.target     # active
systemctl --user --failed                               # empty
pgrep -c hyprpaper                                      # 1
qs -c quantum-moon ipc show                             # the IPC surface
```

Pick a planet: `qm-random`, or open the Quantum Moon panel from the bar logo.

## 5. Optional

- `qm-fetch-videos` then `qm-apply --persisted` for the centre-monitor videos.
- `~/.config/quantum-moon/vpn.json`: the NetworkManager connection the bar's VPN glyph toggles.
- `~/.config/quantum-moon/git-watcher.json`: Azure DevOps PR watcher (needs a PAT); the `quantum-moon-git-watcher` unit starts once the file exists.
- `~/.config/quantum-moon/services.json`: paths for the Docker/Ollama/Open WebUI and KVM panels.
- `qm-backup init` then `qm-backup run --dry-run`: borg backups to `/mnt/Backup` (the timer runs daily at 03:30 when the mount exists).
- `extras/middle-mouse-debounce/`: a system service that debounces a flaky middle button.

## 6. Updating

```sh
cd ~/Projects/Quantum-Moon && git pull && ./scripts/install.sh --quick && qm-restart-shell
```

`qm-update` opens a terminal that runs the system update (`pacman -Syu` + `yay -Sua`).

## 7. Uninstall

Remove the symlinks and units created by `install.sh` (the dry run lists them) and the `~/.config/quantum-moon`, `~/.local/state/quantum-moon`, `~/.local/share/quantum-moon` directories. Package removal is up to you; `config/packages/*.txt` lists what was installed.

## 8. Legal

All intellectual property in *Outer Wilds* belongs to Mobius Digital, Annapurna Interactive and their licensors. Quantum Moon is a free, fan-made homage, not affiliated with or endorsed by them. Original code and configuration here is MIT licensed (see `LICENSE`); that does not extend to game assets or bundled third-party media.
