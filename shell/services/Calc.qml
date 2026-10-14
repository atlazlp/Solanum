pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// `qalc -t <expr>` evaluator, debounced 120 ms. `result` is the last successful text, `error`
// flags qalc error/warning output, `copy()` puts the result on the clipboard.
Singleton {
    id: root

    property string expression: ""
    property string result: ""
    property bool error: false
    property bool busy: false
    readonly property bool hasResult: result !== "" && !error

    function evaluate(expr: string): void {
        expression = (expr ?? "").trim();
        if (!expression) {
            result = "";
            error = false;
            debounce.stop();
            return;
        }
        debounce.restart();
    }

    function copy(): void {
        if (hasResult)
            Quickshell.execDetached(["wl-copy", result]);
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            if (proc.running)
                proc.signal(15);
            proc.pending = root.expression;
            proc.command = ["env", "LC_ALL=C", "qalc", "-t", root.expression];
            proc.running = true;
        }
    }

    Process {
        id: proc
        property string pending: ""
        onRunningChanged: root.busy = running
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.pending !== root.expression)
                    return;
                const t = text.trim();
                root.error = /^(error|warning):/i.test(t) || t === "";
                root.result = t;
            }
        }
    }
}
