-- autostart.lua: exec-once equivalents, run once per compositor start (hl.on "hyprland.start"), never at load
-- (a top-level hl.exec_cmd is `exec`: it re-runs on every reload and segfaults under --verify-config).
--
-- Always: uwsm finalize (only under a UWSM session), cliphist watchers, trash-empty, cursor, hyprresume,
-- autolock on login, polkit agent (hyprpolkitagent). Non-UWSM fallback (Phase 1-3 plain SDDM session):
-- the daemons that Phase 4 turns into user units (shell, hyprpaper, hyprsunset, qm-apply + qm-video-watch,
-- lan-mouse/llm-tray sessions, audio inhibit, suspend-resume watch). Dropped from caelestia execs.conf on
-- purpose: gnome-keyring, geoclue, gammastep, mpris-proxy, `caelestia resizer -d`.
local U, S = QM.util, QM.shell

-- uwsm check is-active has no -q (only -v); a bogus -q made the check always fail.
local UWSM_ACTIVE = "command -v uwsm >/dev/null 2>&1 && uwsm check is-active 2>/dev/null"

-- Run cmd only when the session is NOT managed by UWSM (units own it there).
local function unless_uwsm(cmd)
  return "sh -c " .. U.shq("if " .. UWSM_ACTIVE .. "; then exit 0; fi; " .. cmd)
end

local function unless_running(pattern, cmd)
  return "pgrep -f " .. U.shq(pattern) .. " >/dev/null 2>&1 || " .. cmd
end

hl.on("hyprland.start", function()
  local X = hl.exec_cmd

  -- UWSM session: finish the unit graph so graphical-session.target becomes active.
  X("sh -c " .. U.shq(UWSM_ACTIVE .. " && uwsm finalize"))

  -- Clipboard history
  X("wl-paste --type text --watch cliphist store")
  X("wl-paste --type image --watch cliphist store")

  -- Auto delete trash 30 days old
  X("trash-empty 30")

  -- Cursors
  X("hyprctl setcursor " .. QM.cursor.theme .. " " .. QM.cursor.size)
  X("gsettings set org.gnome.desktop.interface cursor-theme '" .. QM.cursor.theme .. "'")
  X("gsettings set org.gnome.desktop.interface cursor-size " .. QM.cursor.size)

  -- Session restore
  X("hyprresume -c " .. U.CFG_DIR .. "/hyprresume.toml")

  -- Lock right after login (pairs with SDDM autologin)
  X(U.script("qm-autolock-on-login"))

  -- ===== Non-UWSM fallback branch =====
  X(unless_uwsm(S.start))
  X(unless_uwsm("sleep 1; pgrep -x hyprpaper >/dev/null || exec hyprpaper"))
  X(unless_uwsm("command -v hyprsunset >/dev/null 2>&1 || exit 0; pgrep -x hyprsunset >/dev/null || exec hyprsunset -c " .. U.CFG_DIR .. "/hyprsunset.conf"))
  -- Quantum Moon: pull LFS videos if needed, apply the persisted planet, then watch the center video.
  -- Not `exec`-ed at reload: a reload must not respawn the center video during game mode.
  X(unless_uwsm(
    "QM=" .. U.shq(U.QM_ROOT) .. "; repo=\"$(dirname \"$QM\")\"; "
    .. "command -v git-lfs >/dev/null && [ -d \"$repo/.git\" ] && (cd \"$repo\" && git lfs pull --include=\"solanum/modes/*/wallpapers/center.mp4\") || true; "
    .. "sleep 2; \"$QM/scripts/qm-apply\" --persisted; "
    .. unless_running("[q]m-video-watch", "exec \"$QM/scripts/qm-video-watch\"")))
  -- Lan Mouse tray + daemon (lan-kvm-hyprland) and local LLM tray (Ollama + Open WebUI)
  X(unless_uwsm(unless_running("[l]an-mouse-tray.py", "exec bash " .. U.HOME .. "/Projects/lan-kvm-hyprland/arch-hyprland/scripts/lan-mouse-session.sh")))
  X(unless_uwsm(unless_running("[l]lm-tray.py", "exec bash " .. U.HOME .. "/Projects/gemma4-heretic/llm-tray-session.sh")))
  -- Block sleep while audio plays
  X(unless_uwsm(unless_running("[i]nhibit-sleep-while-audio-playback.sh", "exec sh " .. U.script("inhibit-sleep-while-audio-playback.sh"))))
  -- Suspend/resume watcher (Phase 1: caelestia-suspend-resume-watch.service still runs the live copy; skip if so)
  X(unless_uwsm("systemctl --user is-active -q caelestia-suspend-resume-watch.service && exit 0; "
    .. unless_running("[s]uspend-resume-watch.sh", "exec bash " .. U.script("suspend-resume-watch.sh"))))
  -- Polkit agent for Shelly UI / pkexec / asroot. Always ensure one is up: plain
  -- start-hyprland never activates graphical-session.target, so the stock
  -- hyprpolkitagent user unit alone stays dead without a drop-in + this start.
  X(unless_running("[h]yprpolkitagent|[p]olkit-gnome-authentication-agent-1",
    "systemctl --user start hyprpolkitagent.service 2>/dev/null"
      .. " || exec /usr/lib/hyprpolkitagent/hyprpolkitagent"
      .. " || exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"))
end)
