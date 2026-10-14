import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config
import qs.services

// Shared PAM state for every lock surface: one password buffer fed by ANY screen's key events,
// a "passwd" context and an optional "fprint" context (when `fprintd-list $USER` succeeds).
// Ported from caelestia modules/lock/Pam.qml; success -> Lock.unlock().
Scope {
    id: root

    // Set by the host from WlSessionLock.secure: the compositor has shown our surfaces.
    property bool secure: false
    // False in the preview host: key handling and PAM starts are no-ops.
    property bool enabled: true

    readonly property alias passwd: passwd
    readonly property alias fprint: fprint
    property string lockMessage
    property string state           // "" | "fail" | "error" | "max"
    property string fprintState     // "" | "fail" | "error" | "max"
    property string buffer
    property bool showPassword: false

    readonly property bool enableFprint: Config.get("lock.enableFprint", true) !== false
    readonly property int maxFprintTries: Config.get("lock.maxFprintTries", 3)
    readonly property bool busy: passwd.active

    signal flashMsg()
    signal failed()

    function handleKey(event: var): void {
        if (!root.enabled || passwd.active || state === "max")
            return;

        if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            root.submit();
        } else if (event.key === Qt.Key_Escape) {
            buffer = "";
        } else if (event.key === Qt.Key_Backspace) {
            if (event.modifiers & Qt.ControlModifier)
                buffer = "";
            else
                buffer = buffer.slice(0, -1);
        } else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
            buffer = "";
        } else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
            root.showPassword = !root.showPassword;
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            // Anything except control characters
            buffer += event.text;
        }
    }

    function submit(): void {
        if (!root.enabled || passwd.active || state === "max")
            return;
        passwd.start();
    }

    function reset(): void {
        buffer = "";
        state = "";
        fprintState = "";
        lockMessage = "";
        showPassword = false;
    }

    PamContext {
        id: passwd

        config: "passwd"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.lockMessage = message;
            else if (root.lockMessage && message.endsWith(" left to unlock)"))
                root.lockMessage += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;

            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                Lock.unlock();
                return;
            }

            if (res === PamResult.Error)
                root.state = "error";
            else if (res === PamResult.MaxTries)
                root.state = "max";
            else if (res === PamResult.Failed)
                root.state = "fail";

            root.flashMsg();
            root.failed();
            stateReset.restart();
        }
    }

    PamContext {
        id: fprint

        property bool available: false
        property int tries: 0
        property int errorTries: 0

        function checkAvail(): void {
            if (!available || !root.enableFprint || !root.secure || !root.enabled) {
                abort();
                return;
            }

            tries = 0;
            errorTries = 0;
            start();
        }

        config: "fprint"
        configDirectory: Quickshell.shellDir + "/assets/pam.d"

        onCompleted: res => {
            if (!available)
                return;

            if (res === PamResult.Success) {
                Lock.unlock();
                return;
            }

            if (res === PamResult.Error) {
                root.fprintState = "error";
                errorTries++;
                if (errorTries < 5) {
                    abort();
                    errorRetry.restart();
                }
            } else if (res === PamResult.MaxTries) {
                // pam_fprintd max-tries=1: every miss reports MaxTries; count our own tries.
                tries++;
                if (tries < root.maxFprintTries) {
                    root.fprintState = "fail";
                    start();
                } else {
                    root.fprintState = "max";
                    abort();
                }
            }

            root.flashMsg();
            fprintStateReset.start();
        }
    }

    Process {
        id: availProc

        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$USER\""]
        onExited: code => {
            fprint.available = code === 0;
            fprint.checkAvail();
        }
    }

    Timer {
        id: errorRetry

        interval: 800
        onTriggered: fprint.start()
    }

    Timer {
        id: stateReset

        interval: 4000
        onTriggered: {
            if (root.state !== "max")
                root.state = "";
        }
    }

    Timer {
        id: fprintStateReset

        interval: 4000
        onTriggered: {
            root.fprintState = "";
            fprint.errorTries = 0;
        }
    }

    onSecureChanged: {
        if (root.secure) {
            root.reset();
            if (root.enabled)
                availProc.running = true;
        } else {
            fprint.abort();
        }
    }

    onEnableFprintChanged: fprint.checkAvail()

    Connections {
        target: Lock

        function onUnlockRequested(): void {
            fprint.abort();
        }
    }
}
