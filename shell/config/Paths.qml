pragma Singleton

import Quickshell
import Quickshell.Io
import qs.config

// Every filesystem location the shell touches. Plain strings, no trailing slash.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string config: (Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`) + "/solanum"
    readonly property string state: (Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`) + "/solanum"
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`) + "/solanum"
    readonly property string data: (Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`) + "/solanum"
    readonly property string scripts: `${config}/scripts`
    readonly property string shellDir: Quickshell.shellDir
    readonly property string assets: `${shellDir}/assets`

    // Root of the solanum engine (modes/, palettes/, scripts/). Read from
    // `~/.config/solanum/root`; falls back to QM_ROOT env, then ~/Projects/Quantum-Moon/solanum.
    property string qmRoot: Quickshell.env("QM_ROOT") || `${home}/Projects/Quantum-Moon/solanum`
    readonly property string modes: `${qmRoot}/modes`
    readonly property string scene: `${qmRoot}/scene`

    readonly property string shellConfig: `${config}/shell.json`
    readonly property string scheme: `${state}/scheme.json`
    readonly property string currentMode: `${state}/current.json`
    readonly property string screensRuntime: `${state}/screens-runtime.json`

    function expand(p: string): string {
        if (!p)
            return "";
        if (p.startsWith("~/"))
            return home + p.slice(1);
        return p;
    }

    function fileUrl(p: string): string {
        return p.startsWith("file://") ? p : "file://" + p;
    }

    FileView {
        path: `${root.config}/root`
        watchChanges: true
        printErrors: false
        onLoaded: {
            const t = text().trim();
            if (t.length > 0)
                root.qmRoot = root.expand(t);
        }
        onFileChanged: reload()
        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                console.warn("Paths: cannot read", path, err);
        }
    }
}
