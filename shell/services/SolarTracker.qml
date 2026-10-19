pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Live solar.json from the Godot wallpaper (body screen positions + cava rings).
Singleton {
    id: root

    readonly property string solarPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/solanum/solar.json`
    property var data: ({})
    property int rev: 0
    property int configRev: 0

    Connections {
        target: Config
        function onReload(): void {
            root.configRev++;
        }
    }

    readonly property string ringMode: {
        void configRev;
        return String(Config.get("quantumMoon.background.visualiser.ringMode", "follow_solanum"));
    }
    readonly property string fixedPlanet: {
        void configRev;
        return String(Config.get("quantumMoon.background.visualiser.fixedPlanet", "giants_deep"));
    }
    readonly property string qmHost: String(data?.qm_host ?? "")

    // qm_host id → solar.json body / rings key
    readonly property var hostToBody: ({
        ember_twin: "hourglass_twins",
        "ember-twin": "hourglass_twins",
        "hourglass-twins": "hourglass_twins",
        hourglass_twins: "hourglass_twins",
        timber_hearth: "timber_hearth",
        "timber-hearth": "timber_hearth",
        brittle_hollow: "brittle_hollow",
        "brittle-hollow": "brittle_hollow",
        giants_deep: "giants_deep",
        "giants-deep": "giants_deep",
        dark_bramble: "dark_bramble",
        "dark-bramble": "dark_bramble"
    })

    readonly property string activeBodyId: {
        void rev;
        if (ringMode === "fixed")
            return hostToBody[fixedPlanet] || fixedPlanet || "giants_deep";
        return hostToBody[qmHost] || "timber_hearth";
    }

    readonly property var rings: data?.rings ?? ({})
    readonly property var giantsDeepRing: data?.giants_deep_ring ?? rings?.giants_deep ?? null
    readonly property var activeRing: {
        void rev;
        void ringMode;
        void fixedPlanet;
        const id = activeBodyId;
        const fromMap = rings?.[id];
        if (fromMap && fromMap.visible && (fromMap.r_px ?? 0) > 1)
            return fromMap;
        if (id === "giants_deep" && giantsDeepRing && giantsDeepRing.visible && (giantsDeepRing.r_px ?? 0) > 1)
            return giantsDeepRing;
        return null;
    }
    readonly property bool hasRing: !!(activeRing && activeRing.visible && (activeRing.r_px ?? 0) > 1)

    readonly property string hoverBody: String(data?.hover_body ?? "")
    readonly property bool sunHovered: hoverBody === "sun"
    readonly property var sunBody: data?.bodies?.sun ?? null
    readonly property bool supernovaActive: !!(data?.supernova_active)

    function reload(): void {
        view.reload();
    }

    function setMenuHold(held: bool): void {
        holdProc.running = false;
        holdProc.command = ["qm-godot-ipc", "menu-hold", held ? "true" : "false"];
        holdProc.running = true;
    }

    function triggerSupernova(): void {
        snProc.running = false;
        snProc.command = ["qm-godot-ipc", "supernova"];
        snProc.running = true;
    }

    function orbitBody(bodyId: string): void {
        orbitProc.running = false;
        orbitProc.command = ["qm-godot-ipc", "orbit", String(bodyId)];
        orbitProc.running = true;
    }

    function returnOverview(): void {
        overviewProc.running = false;
        overviewProc.command = ["qm-godot-ipc", "overview"];
        overviewProc.running = true;
    }

    property string pendingVideoBody: ""
    readonly property string planetVideoPath: `${Paths.state}/planet-video.body`
    property string planetVideoBody: ""

    function playPlanetVideo(bodyId: string): void {
        pendingVideoBody = String(bodyId);
        videoProc.running = false;
        videoProc.command = ["qm-godot-ipc", "video", pendingVideoBody];
        videoProc.running = true;
    }

    function restoreScene(how: string): void {
        restoreProc.running = false;
        restoreProc.command = ["qm-godot-ipc", "restore-scene", how];
        restoreProc.running = true;
    }

    function _maybeCutVideo(): void {
        if (!pendingVideoBody.length || !data?.video_ready || cutProc.running)
            return;
        const body = pendingVideoBody;
        pendingVideoBody = "";
        cutProc.running = false;
        cutProc.command = ["qm-godot-ipc", "cut-video", body];
        cutProc.running = true;
    }

    Process {
        id: holdProc
    }

    Process {
        id: snProc
    }

    Process {
        id: orbitProc
    }

    Process {
        id: overviewProc
    }

    Process {
        id: videoProc
    }

    Process {
        id: cutProc
    }

    Process {
        id: restoreProc
    }

    FileView {
        id: planetVideoFile
        path: root.planetVideoPath
        watchChanges: true
        printErrors: false
        onLoaded: root.planetVideoBody = text().trim()
        onFileChanged: planetVideoFile.reload()
        onLoadFailed: root.planetVideoBody = ""
    }

    FileView {
        id: view
        path: root.solarPath
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.data = JSON.parse(text());
                root.rev++;
                root._maybeCutVideo();
            } catch (e) {
                // keep last good frame
            }
        }
        onFileChanged: reload()
        onLoadFailed: root.data = ({})
    }

    Timer {
        interval: 100
        running: QuantumMoonWallpaper.centerUsesScene()
        repeat: true
        onTriggered: {
            if (view.path)
                view.reload();
        }
    }
}
