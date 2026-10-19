-- binds/shell.lua: everything that targets the shell or caelestia-cli (keybinds.conf 8-35, 163-189 + hypr-user.conf).
-- All strings come from lib/shell.lua so the Phase 3 flip touches one file.
local U, B, S = QM.util, QM.binds, QM.shell
local L = { locked = true }

-- Misc
hl.bind("CTRL + ALT + Delete", B.global("session"))
hl.bind("SUPER + N", B.global("sidebar"))
hl.bind("CTRL + ALT + C", B.global("clearNotifs"), L)
hl.bind("SUPER + K", B.global("showall"))
hl.bind("SUPER + L", B.global("lock"))

-- Restore lock: restart the shell, then lock (both fire)
hl.bind("SUPER + ALT + L", B.exec(S.start), L)
hl.bind("SUPER + ALT + L", B.global("lock"), L)

-- Kill / restart shell (bindr: fire on release)
hl.bind("CTRL + SUPER + SHIFT + R", B.exec(S.kill), { release = true })
hl.bind("CTRL + SUPER + ALT + R", B.exec(S.restart), { release = true })

-- Window picker (workspace-overview-toggle.sh all: Hyprspace is not loaded, so the shell picker)
hl.bind("SUPER + D", B.exec(S.window_picker))

-- Utilities
hl.bind("Print", B.exec(S.screenshot .. " freeze"), L)     -- region picker (frozen), then edit
hl.bind("SUPER + SHIFT + S", B.global("screenshotFreeze")) -- capture region (freeze)
hl.bind("SUPER + SHIFT + ALT + S", B.global("screenshot")) -- capture region
hl.bind("SUPER + ALT + R", B.exec(S.record .. " -s"))      -- record screen with sound
hl.bind("CTRL + ALT + R", B.exec(S.record))                -- record screen
hl.bind("SUPER + SHIFT + ALT + R", B.exec(S.record .. " -r")) -- record region

-- Clipboard and emoji picker
hl.bind("SUPER + V", B.exec(S.clipboard))
hl.bind("SUPER + ALT + V", B.exec(S.clipboard_delete))
hl.bind("SUPER + Period", B.exec(S.emoji))
hl.bind("CTRL + SHIFT + ALT + V", B.exec([[sleep 0.5s && ydotool type -d 1 "$(cliphist list | head -1 | cliphist decode)"]]), L) -- alternate paste

-- Sleep
hl.bind("SUPER + SHIFT + L", B.exec("systemctl suspend-then-hibernate"), L)

-- Testing
hl.bind("SUPER + ALT + F12", B.exec([[notify-send -u low -i dialog-information-symbolic 'Test notification' "Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!" -a 'Shell' -A "Test1=I got it!" -A "Test2=Another action"]]), L)
