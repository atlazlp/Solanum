pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.modules.launcher.items

// Result list for the apps / actions / clip modes. `values` is computed from `mode` + `query`;
// the delegate switches with the mode. Up to `maxShown` rows are visible (44 px each).
NomaiList {
    id: root

    property string mode: "apps"      // apps | actions | clip
    property string query: ""
    property int maxShown: Config.launcher.maxShown ?? 10
    readonly property int rowHeight: 44
    property bool revealing: false
    property bool hoverSelects: true
    property int wantedIndex: 0

    signal launchApp(var app)
    signal editRequested(var target)
    signal runAction(var action)
    signal copyClip(var entry)
    signal pinClip(var entry)
    signal deleteClip(var entry)

    readonly property list<var> values: {
        switch (mode) {
        case "actions": {
            const q = query.trim().toLowerCase();
            const acts = Config.launcher.actions ?? [];
            if (!q)
                return acts;
            return acts.filter(a => `${a.name ?? ""} ${a.description ?? ""}`.toLowerCase().includes(q));
        }
        case "clip":
            return Clipboard.search(query);
        default:
            return AppIndex.search(query);
        }
    }

    function select(i: int, dir: int): void {
        wantedIndex = Math.max(0, Math.min(i, count - 1));
        currentIndex = wantedIndex;
    }

    function moveBy(delta: int): void {
        if (count === 0)
            return;
        let i = currentIndex + delta;
        if (Math.abs(delta) === 1)
            i = (i + count) % count;
        select(i, delta < 0 ? -1 : 1);
    }

    function activateCurrent(): void {
        const v = values[currentIndex];
        if (!v)
            return;
        switch (mode) {
        case "actions":
            runAction(v);
            break;
        case "clip":
            copyClip(v);
            break;
        default:
            launchApp(v);
        }
    }

    function editCurrent(): void {
        const item = currentItem;
        if (item && typeof item.editTarget === "function")
            editRequested(item.editTarget());
    }

    function deleteCurrent(): void {
        const v = values[currentIndex];
        if (v && mode === "clip")
            deleteClip(v);
    }

    function pinCurrent(): void {
        const v = values[currentIndex];
        if (v && mode === "clip")
            pinClip(v);
    }

    function revealNow(): void {
        revealing = true;
        for (const c of contentItem.children)
            if (typeof c.reveal === "function")
                c.reveal();
        revealTimer.restart();
    }

    Timer {
        id: revealTimer
        interval: Motion.panelOpen + Motion.glyphStagger * Motion.glyphStaggerMax
        onTriggered: root.revealing = false
    }

    onModeChanged: {
        wantedIndex = 0;
        revealNow();
    }
    onQueryChanged: wantedIndex = 0

    model: ScriptModel {
        values: root.values
        // ScriptModel diffs the list and the view follows the old current item; re-apply ours.
        onValuesChanged: Qt.callLater(() => root.currentIndex = Math.max(0, Math.min(root.wantedIndex, root.count - 1)))
    }

    delegate: root.mode === "actions" ? actionDelegate : (root.mode === "clip" ? clipDelegate : appDelegate)

    implicitHeight: Math.max(rowHeight, Math.min(count, maxShown) * (rowHeight + spacing) - spacing)

    Component {
        id: appDelegate
        AppItem {
            onLaunchRequested: app => root.launchApp(app)
            onEditRequested: target => root.editRequested(target)
        }
    }

    Component {
        id: actionDelegate
        ActionItem {
            onRunRequested: action => root.runAction(action)
        }
    }

    Component {
        id: clipDelegate
        ClipItem {
            onCopyRequested: entry => root.copyClip(entry)
            onPinToggled: entry => root.pinClip(entry)
            onDeleteRequested: entry => root.deleteClip(entry)
        }
    }

    GlyphText {
        anchors.centerIn: parent
        visible: root.count === 0
        text: {
            if (root.mode === "clip")
                return Clipboard.busy ? "Loading clipboard…" : (root.query ? "No matching entries" : "Clipboard history is empty");
            return root.query ? "No results" : "Nothing here";
        }
        dim: true
    }
}
