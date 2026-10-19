pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import qs.modules.launcher.items
import qs.modules.windowpicker

// Launcher panel (bottom centre). Header = 5 HexButton mode tabs + search field; body switches
// with the mode: apps / actions / clip (LauncherList), windows (WindowList), emoji (grid), calc (card).
// Keyboard: typing goes to the field, Up/Down move, Enter activates, Esc closes, Ctrl+1..5 pick a
// mode, F2 edits the current app/window, Delete kills (windows) / deletes (clip).
Item {
    id: root

    property var screen: null
    property var visibilities: null
    property var slot: null

    readonly property int panelWidth: Config.launcher.width ?? 640
    readonly property var prefixes: Config.launcher.prefixes ?? ({})
    readonly property list<var> tabs: [
        { mode: "apps", icon: "apps", label: "Apps" },
        { mode: "windows", icon: "select_window", label: "Windows" },
        { mode: "clip", icon: "content_paste", label: "Clip" },
        { mode: "emoji", icon: "mood", label: "Emoji" },
        { mode: "calc", icon: "calculate", label: "Calc" }
    ]

    property string mode: "apps"
    readonly property string text: search.text

    // Prefix typed into the field overrides the tab mode.
    readonly property string prefixMode: {
        for (const m of ["actions", "windows", "clip", "emoji", "calc"]) {
            const p = prefixes[m];
            if (p && text.startsWith(p))
                return m;
        }
        return "";
    }
    readonly property string effectiveMode: prefixMode || mode
    readonly property string query: prefixMode ? text.slice(prefixes[prefixMode].length) : text

    readonly property bool modalOpen: editor.open || killConfirm.open
    readonly property int modalHeight: editor.open ? 520 : 240

    implicitWidth: panelWidth
    // Modals are centred over the panel area, so the panel grows to fit them while one is open.
    implicitHeight: Math.max(frame.implicitHeight, modalOpen ? modalHeight : 0)

    focus: true
    Keys.forwardTo: [search.input]

    function reveal(): void {
        consumeRequestedMode();
        if (effectiveMode === "clip")
            Clipboard.refresh();
        const body = bodyLoader.item;
        if (body && typeof body.revealNow === "function")
            body.revealNow();
        root.forceActiveFocus();
        Qt.callLater(() => search.forceFocus());
    }

    function consumeRequestedMode(): void {
        const m = LauncherState.consume();
        if (m)
            setMode(m);
    }

    function setMode(m: string): void {
        if (!LauncherState.modes.includes(m))
            return;
        if (prefixMode && prefixMode !== m)
            search.text = "";
        mode = m;
        if (m === "clip")
            Clipboard.refresh();
        root.forceActiveFocus();
    }

    function close(): void {
        Visibilities.close("launcher", root.visibilities);
    }

    function activate(): void {
        const body = bodyLoader.item;
        if (!body)
            return;
        switch (effectiveMode) {
        case "calc":
            if (Calc.hasResult) {
                Calc.copy();
                Toaster.toast("Copied", Calc.result, "calculate", "success", 2000);
                close();
            }
            break;
        case "emoji":
            if (typeof body.useCurrent === "function")
                body.useCurrent();
            break;
        default:
            if (typeof body.activateCurrent === "function")
                body.activateCurrent();
        }
    }

    function launchApp(app: var): void {
        AppIndex.launch(app);
        close();
    }

    function runAction(action: var): void {
        const cmd = action?.command ?? [];
        if (cmd.length === 0)
            return;
        if (cmd[0] === "mode" && cmd.length > 1) {
            search.text = "";
            setMode(cmd[1]);
            return;
        }
        Quickshell.execDetached(cmd);
        close();
    }

    function copyClip(entry: var): void {
        Clipboard.copy(entry);
        close();
    }

    function useEmoji(entry: var): void {
        Emoji.use(entry);
        close();
    }

    function openEditor(target: var): void {
        editor.edit(target);
    }

    onEffectiveModeChanged: {
        if (effectiveMode === "clip")
            Clipboard.refresh();
    }

    onQueryChanged: {
        if (effectiveMode === "calc")
            Calc.evaluate(query);
    }

    Connections {
        target: LauncherState
        function onModeRequested(m: string): void {
            if (m && root.visibilities?.launcher)
                root.consumeRequestedMode();
        }
    }

    Connections {
        target: search.input
        function onActiveFocusChanged(): void {
            // Keep key routing on the panel root (Keys.forwardTo feeds the field).
            if (search.input.activeFocus && !editor.open && !killConfirm.open)
                root.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        if (handleKey(event.key, event.modifiers))
            event.accepted = true;
    }

    // Returns true when the key was consumed (otherwise it is forwarded to the search field).
    function handleKey(key: int, modifiers: int): bool {
        if (editor.open || killConfirm.open)
            return false;
        const ctrl = modifiers & Qt.ControlModifier;
        if (ctrl && key >= Qt.Key_1 && key <= Qt.Key_5) {
            setMode(tabs[key - Qt.Key_1].mode);
            return true;
        }
        const body = bodyLoader.item;
        switch (key) {
        case Qt.Key_Escape:
            close();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            activate();
            return true;
        case Qt.Key_Up:
        case Qt.Key_Down:
        case Qt.Key_PageUp:
        case Qt.Key_PageDown:
            if (body && typeof body.navigate === "function")
                body.navigate(key);
            return true;
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (effectiveMode === "emoji" && body && typeof body.navigate === "function") {
                body.navigate(key);
                return true;
            }
            return false;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            if (body && typeof body.navigate === "function")
                body.navigate(key === Qt.Key_Tab ? Qt.Key_Down : Qt.Key_Up);
            return true;
        case Qt.Key_F2:
            if (body && typeof body.editCurrent === "function")
                body.editCurrent();
            return true;
        case Qt.Key_Delete:
            if (effectiveMode === "windows" && body && typeof body.killCurrent === "function") {
                body.killCurrent();
                return true;
            }
            if (effectiveMode === "clip" && body && typeof body.deleteCurrent === "function") {
                body.deleteCurrent();
                return true;
            }
            return false;
        }
        return false;
    }

    NomaiFrame {
        id: frame
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: implicitHeight
        padding: Theme.spaceLg
        chamfer: Theme.chamferLg
        fill: Theme.ink
        glow: true
        ticks: true
        implicitHeight: column.implicitHeight + padding * 2

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.spaceMd

            Row {
                id: header
                width: parent.width
                spacing: Theme.spaceSm

                Repeater {
                    model: root.tabs
                    HexButton {
                        required property var modelData
                        required property int index
                        shape: "hex"
                        icon: modelData.icon
                        active: root.effectiveMode === modelData.mode
                        tooltip: `${modelData.label}  (Ctrl+${index + 1})`
                        padding: Theme.spaceMd
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.setMode(modelData.mode)
                    }
                }

                NomaiTextField {
                    id: search
                    width: header.width - header.spacing * 5 - tabsWidth()
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "search"
                    placeholder: {
                        switch (root.effectiveMode) {
                        case "windows": return "Filter windows";
                        case "clip": return "Search clipboard";
                        case "emoji": return "Search emoji";
                        case "calc": return "Expression";
                        case "actions": return "Action";
                        default: return `Search apps  ·  ${root.prefixes.actions ?? ">"} actions`;
                        }
                    }
                    input.cursorVisible: true

                    function tabsWidth(): real {
                        let w = 0;
                        for (let i = 0; i < header.children.length; i++) {
                            const c = header.children[i];
                            if (c !== search && c.visible && c.implicitWidth)
                                w += c.implicitWidth;
                        }
                        return w;
                    }
                }
            }

            Loader {
                id: bodyLoader
                width: parent.width
                sourceComponent: {
                    switch (root.effectiveMode) {
                    case "windows": return windowsBody;
                    case "emoji": return emojiBody;
                    case "calc": return calcBody;
                    default: return listBody;
                    }
                }
                onLoaded: {
                    if (item && typeof item.revealNow === "function")
                        item.revealNow();
                }
            }
        }
    }

    Component {
        id: listBody
        LauncherList {
            mode: root.effectiveMode
            query: root.query
            onLaunchApp: app => root.launchApp(app)
            onEditRequested: target => root.openEditor(target)
            onRunAction: action => root.runAction(action)
            onCopyClip: entry => root.copyClip(entry)
            onPinClip: entry => Clipboard.togglePin(entry)
            onDeleteClip: entry => Clipboard.remove(entry)
            function navigate(key: int): void {
                if (key === Qt.Key_Up) moveBy(-1);
                else if (key === Qt.Key_Down) moveBy(1);
                else if (key === Qt.Key_PageUp) moveBy(-maxShown);
                else if (key === Qt.Key_PageDown) moveBy(maxShown);
            }
        }
    }

    Component {
        id: windowsBody
        WindowList {
            grouped: false
            query: root.query
            active: root.visibilities?.launcher ?? true
            onFocusRequested: row => {
                Hypr.dispatch(`focuswindow address:${row.address}`);
                root.close();
            }
            onKillRequested: row => killConfirm.ask(row)
            onEditRequested: target => root.openEditor(target)
            function navigate(key: int): void {
                if (key === Qt.Key_Up) moveBy(-1);
                else if (key === Qt.Key_Down) moveBy(1);
                else if (key === Qt.Key_PageUp) moveBy(-maxShown);
                else if (key === Qt.Key_PageDown) moveBy(maxShown);
            }
        }
    }

    Component {
        id: calcBody
        CalcItem {
            expression: root.query
            onCopyRequested: root.activate()
            Component.onCompleted: Calc.evaluate(root.query)
            function revealNow(): void {}
        }
    }

    Component {
        id: emojiBody
        Column {
            id: emojiCol
            spacing: Theme.spaceSm

            readonly property int columns: Config.launcher.emojiColumns ?? 8
            readonly property int cellW: Math.floor(width / columns)
            readonly property int cellH: 44
            readonly property int visibleRows: 5
            readonly property list<var> results: Emoji.search(root.query, 400)

            function useCurrent(): void {
                const e = grid.currentIndex >= 0 ? results[grid.currentIndex] : null;
                if (e)
                    root.useEmoji(e);
            }

            function navigate(key: int): void {
                if (grid.count === 0)
                    return;
                switch (key) {
                case Qt.Key_Up: grid.moveCurrentIndexUp(); break;
                case Qt.Key_Down: grid.moveCurrentIndexDown(); break;
                case Qt.Key_Left: grid.moveCurrentIndexLeft(); break;
                case Qt.Key_Right: grid.moveCurrentIndexRight(); break;
                case Qt.Key_PageUp: grid.currentIndex = Math.max(0, grid.currentIndex - columns * visibleRows); break;
                case Qt.Key_PageDown: grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + columns * visibleRows); break;
                }
            }

            function revealNow(): void {
                reveal.trigger();
            }

            onResultsChanged: Qt.callLater(() => grid.currentIndex = 0)

            GlyphReveal {
                id: reveal
                width: parent.width
                autoTrigger: false
                visible: root.query === "" && Emoji.recent.length > 0
                implicitHeight: visible ? recentCol.implicitHeight : 0

                Column {
                    id: recentCol
                    width: parent.width
                    spacing: Theme.spaceXs

                    SectionHeader { text: "Recent" }

                    Row {
                        spacing: 0
                        Repeater {
                            model: Emoji.recentEntries.slice(0, emojiCol.columns)
                            EmojiItem {
                                width: emojiCol.cellW
                                height: emojiCol.cellH
                                onClicked: root.useEmoji(modelData)
                            }
                        }
                    }

                    SectionHeader { text: "All" }
                }
            }

            GridView {
                id: grid
                width: parent.width
                height: Math.max(emojiCol.cellH, Math.min(Math.ceil(count / emojiCol.columns), emojiCol.visibleRows) * emojiCol.cellH)
                clip: true
                cellWidth: emojiCol.cellW
                cellHeight: emojiCol.cellH
                model: ScriptModel { values: emojiCol.results }
                keyNavigationWraps: false
                highlightMoveDuration: Motion.fast
                highlightFollowsCurrentItem: true
                highlight: NomaiFrame {
                    padding: 0
                    chamfer: Theme.chamferSm
                    fill: Theme.alpha(Theme.line, 0.12)
                    lineColor: Theme.line
                    glow: true
                }
                delegate: EmojiItem {
                    width: emojiCol.cellW
                    height: emojiCol.cellH
                    onClicked: root.useEmoji(modelData)
                    onHoveredChanged: if (hovered) grid.currentIndex = index
                }

                GlyphText {
                    anchors.centerIn: parent
                    visible: grid.count === 0
                    text: Emoji.all.length === 0 ? "No emoji data (run scripts/qm-gen-emoji.py)" : "No matching emoji"
                    dim: true
                }
            }
        }
    }

    ItemEditor {
        id: editor
        onClosed: root.forceActiveFocus()
    }

    KillConfirm {
        id: killConfirm
        onConfirmed: root.forceActiveFocus()
        onCancelled: root.forceActiveFocus()
    }

    Connections {
        target: LauncherItemOverrides
        function onEditTargetChanged(): void {
            if (LauncherItemOverrides.editTarget && root.visibilities?.launcher) {
                editor.edit(LauncherItemOverrides.editTarget);
                LauncherItemOverrides.closeEditor();
            }
        }
    }
}
