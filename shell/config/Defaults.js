.pragma library

// Every key the UI reads, with its default. The user's shell.json is deep-merged on top.
// Keep this flat-ish and boring: Config.get()/Config.save() address keys as dotted paths.
function defaults() {
    return {
        appearance: {
            fontScale: 1,
            motionScale: 1,
            padding: 1,
            // Role name -> RRGGBB. Layered on top of scheme.json so planet switches keep user colours.
            colourOverrides: {}
        },
        screens: {
            roles: { main: "", left: "", right: "" },
            fallbackMain: ""
        },
        modules: {
            bar: ["main"],
            dashboard: ["main"],
            sidebar: ["main"],
            utilities: ["main"],
            launcher: "*",
            windowPicker: "*",
            quantumMoon: ["main"],
            osd: ["main"],
            notifications: ["main"],
            "lock.fullUi": ["main"],
            "hover.launcher": ["main"],
            "hover.dashboard": ["main"],
            "hover.sidebar": ["main"],
            "hover.quantumMoon": ["main"],
            "hover.audio": ["main", "right"]
        },
        bar: {
            width: 40,
            height: 36,
            entries: [
                { id: "logo", enabled: true },
                { id: "workspaces", enabled: true },
                { id: "spacer", enabled: true },
                { id: "activeWindow", enabled: true },
                { id: "spacer", enabled: true },
                { id: "tray", enabled: true },
                { id: "clock", enabled: true },
                { id: "status", enabled: true },
                { id: "power", enabled: true }
            ],
            status: {
                showAudio: true,
                showMicrophone: true,
                showNetwork: true,
                showWifi: false,
                showVpn: true,
                showGitWatcher: true,
                showUpdates: true,
                showSettings: true,
                showGameMode: true,
                showIdleInhibit: true,
                showRecording: true,
                showNightLight: true,
                showKvm: true
            },
            popouts: { statusIcons: true, tray: true },
            tray: { hiddenIcons: [] },
            workspaces: { perMonitorWorkspaces: true, shown: 5, showWindows: false },
            activeWindow: { showOnHover: false, maxWidth: 420 }
        },
        general: {
            idle: {
                inhibitWhenAudio: true,
                lockTimeout: 1800,
                suspendTimeout: 2100,
                lockedSleepAfter: 300,
                lockBeforeSleep: true,
                // Idle monitors: idleAction is "lock", "dpms off" (hyprctl dispatch) or an argv list.
                // When absent, lockTimeout/suspendTimeout above are used instead.
                timeouts: [
                    { timeout: 1800, idleAction: "lock" },
                    { timeout: 2100, idleAction: ["systemctl", "suspend"] }
                ]
            },
            showOverFullscreen: true,
            lockOnLogin: true
        },
        launcher: {
            enabled: true,
            showOnHover: true,
            maxResults: 40,
            maxShown: 10,
            width: 640,
            prefixes: { actions: ">", windows: ":w ", clip: ":c ", emoji: ":e ", calc: "=" },
            favourites: [],
            hidden: [],
            emojiColumns: 8,
            actions: [
                { name: "Lock", description: "Lock the session", icon: "lock", command: ["qs", "-c", "solanum", "ipc", "call", "lock", "lock"] },
                { name: "Session", description: "Power menu", icon: "power_settings_new", command: ["qs", "-c", "solanum", "ipc", "call", "drawers", "open", "session"] },
                { name: "Settings", description: "Shell settings", icon: "settings", command: ["qs", "-c", "solanum", "ipc", "call", "drawers", "open", "settings"] },
                { name: "Ship log", description: "Open the ship log", icon: "history", command: ["qs", "-c", "solanum", "ipc", "call", "drawers", "open", "shipLog"] },
                { name: "Windows", description: "Switch to window mode", icon: "select_window", command: ["mode", "windows"] },
                { name: "Clipboard", description: "Switch to clipboard mode", icon: "content_paste", command: ["mode", "clip"] },
                { name: "Emoji", description: "Switch to emoji mode", icon: "mood", command: ["mode", "emoji"] },
                { name: "Calculator", description: "Switch to calculator mode", icon: "calculate", command: ["mode", "calc"] },
                { name: "Wipe clipboard", description: "cliphist wipe", icon: "delete_sweep", command: ["cliphist", "wipe"] }
            ]
        },
        notifs: {
            enabled: true,
            actionOnClick: true,
            defaultTimeout: 5000,
            criticalTimeout: 0,
            maxPopups: 5
        },
        osd: {
            enabled: true,
            hideDelay: 2000,
            showMicrophone: true,
            showBrightness: true
        },
        session: {
            enabled: true,
            commands: {
                lock: ["qm-lock"],
                logout: ["qm-lock"],
                suspend: ["systemctl", "suspend"],
                hibernate: ["systemctl", "hibernate"],
                reboot: ["systemctl", "reboot"],
                shutdown: ["systemctl", "poweroff"]
            }
        },
        utilities: {
            enabled: true,
            toasts: {
                configLoaded: false,
                vpnChanged: true,
                gameModeChanged: true,
                audioOutputChanged: true,
                audioInputChanged: true,
                capsLockChanged: false,
                numLockChanged: false,
                kbLayoutChanged: false,
                nowPlaying: false
            },
            recorder: {
                fps: 60,
                audioSource: "default_output"
            }
        },
        sidebar: {
            enabled: true,
            showOnHover: true
        },
        dashboard: {
            enabled: true,
            showOnHover: true,
            resourceUpdateInterval: 3000,
            historyLength: 30,
            weather: {
                location: "",
                useFahrenheit: false,
                useTwelveHourClock: false
            }
        },
        quantumMoon: {
            enabled: true,
            showOnHover: true,
            shuffleOnIdle: true,
            background: {
                enabled: true,
                // "scene" = live Godot solar system on the centre monitor (the Eye still uses its video);
                // "video" = recorded centre video on every planet.
                // sceneRoot empty = the scene shipped in <engine>/scene. A path overrides that.
                centerMode: "scene",
                sceneSpeed: 4.0,
                sceneRoot: "",
                desktopClock: { enabled: true, position: "bottom-right" },
                visualiser: {
                    enabled: true,
                    bars: 128,
                    // "follow_solanum" = ring around Solanum's current host planet;
                    // "fixed" = stay on fixedPlanet.
                    ringMode: "follow_solanum",
                    fixedPlanet: "giants_deep"
                }
            }
        },
        audio: {
            showOnHover: true,
            increment: 0.1,
            maxVolume: 1,
            analogSinkId: "11_00.6.analog-stereo"
        },
        brightness: {
            increment: 0.1
        },
        nightlight: {
            temperature: 4000
        },
        gameMode: {
            autoVpnOff: true,
            pauseVideo: true
        },
        shiplog: {
            maxEntries: 500,
            retentionDays: 30
        },
        updates: {
            interval: 1800,
            checkOnResume: true,
            toast: true,
            command: ""
        },
        git: {
            spawnDaemon: true
        },
        qm: {
            root: ""
        },
        lock: {
            enableFprint: true,
            maxFprintTries: 3,
            hideNotifs: false,
            blur: 48,
            scrim: 0.45
        }
    };
}

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

// Deep merge: objects recurse, arrays and scalars replace. Returns a fresh object.
function merge(base, over) {
    if (!isPlainObject(base))
        return clone(over !== undefined ? over : base);
    const out = {};
    for (const k in base)
        out[k] = clone(base[k]);
    if (isPlainObject(over)) {
        for (const k in over) {
            if (isPlainObject(over[k]) && isPlainObject(out[k]))
                out[k] = merge(out[k], over[k]);
            else
                out[k] = clone(over[k]);
        }
    }
    return out;
}

function clone(v) {
    if (Array.isArray(v))
        return v.map(clone);
    if (isPlainObject(v)) {
        const o = {};
        for (const k in v)
            o[k] = clone(v[k]);
        return o;
    }
    return v;
}

function getPath(obj, dotted, fallback) {
    let cur = obj;
    for (const part of dotted.split(".")) {
        if (!isPlainObject(cur) || !(part in cur))
            return fallback;
        cur = cur[part];
    }
    return cur === undefined ? fallback : cur;
}

function setPath(obj, dotted, value) {
    const parts = dotted.split(".");
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!isPlainObject(cur[parts[i]]))
            cur[parts[i]] = {};
        cur = cur[parts[i]];
    }
    cur[parts[parts.length - 1]] = value;
    return obj;
}
