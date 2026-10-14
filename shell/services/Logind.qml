pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// logind integration via `gdbus monitor`: PrepareForSleep on the manager -> aboutToSleep / resumed,
// Lock / Unlock on this session's object -> lockRequested / unlockRequested.
Singleton {
    id: root

    property bool sleeping: false
    property bool available: false

    signal aboutToSleep()
    signal resumed()
    signal lockRequested()
    signal unlockRequested()

    // D-Bus object paths escape non-alphanumerics as _XX (hex): session "1" -> "_31".
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") ?? ""
    readonly property string sessionPathSuffix: {
        if (!sessionId)
            return "";
        // systemd bus_label_escape: alphanumerics pass through, except a leading digit; rest -> _XX.
        let out = "";
        for (let i = 0; i < sessionId.length; i++) {
            const ch = sessionId[i];
            if (/[A-Za-z0-9]/.test(ch) && !(i === 0 && /[0-9]/.test(ch)))
                out += ch;
            else
                out += "_" + ch.charCodeAt(0).toString(16);
        }
        return `/session/${out}`;
    }

    function handleLine(line: string): void {
        const sleep = line.match(/PrepareForSleep \((true|false)\)/);
        if (sleep) {
            const going = sleep[1] === "true";
            root.sleeping = going;
            if (going)
                root.aboutToSleep();
            else
                root.resumed();
            return;
        }
        const sess = line.match(/^(\S+): org\.freedesktop\.login1\.Session\.(Lock|Unlock) \(\)/);
        if (sess) {
            const path = sess[1];
            if (root.sessionPathSuffix && !path.endsWith(root.sessionPathSuffix))
                return;
            if (sess[2] === "Lock")
                root.lockRequested();
            else
                root.unlockRequested();
        }
    }

    Process {
        id: monitor

        running: true
        // No --object-path: one subscription covers the manager (PrepareForSleep) and every
        // session object (Lock/Unlock); handleLine filters by this session's path.
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => root.handleLine(line)
        }
        onStarted: root.available = true
        onExited: (code, status) => {
            root.available = false;
            console.warn(`Logind: gdbus monitor exited (${code}), restarting in 5 s`);
            restart.restart();
        }
    }

    Timer {
        id: restart

        interval: 5000
        onTriggered: monitor.running = true
    }
}
