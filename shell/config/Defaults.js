.pragma library

// Every key the UI reads, with its default. The user's shell.json is deep-merged on top.
// Keep this flat-ish and boring: Config.get()/Config.save() address keys as dotted paths.
function defaults() {
    return {
        appearance: {
            fontScale: 1,
            motionScale: 1,
            padding: 1
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
            "hover.quantumMoon": ["main"]
        },
        bar: {
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
                lockedSleepAfter: 300
            },
            showOverFullscreen: true,
            lockOnLogin: true
        },
        launcher: {
            enabled: true,
            showOnHover: false,
            maxResults: 40,
            prefixes: { apps: "", windows: "w:", clip: "c:", emoji: "e:", calc: "=" },
            favourites: [],
            hidden: []
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
                lock: ["qs", "-c", "quantum-moon", "ipc", "call", "lock", "lock"],
                logout: ["loginctl", "terminate-user", ""],
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
            }
        },
        quantumMoon: {
            enabled: true,
            showOnHover: true,
            shuffleOnIdle: true
        },
        audio: {
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
            interval: 3600
        },
        qm: {
            root: ""
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
