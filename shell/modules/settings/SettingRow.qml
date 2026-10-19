import QtQuick
import qs.config
import qs.theme
import qs.components

// One setting: label + description on the left, editor on the right (or below when `stacked`).
// `store` is any object with get/has/set/generation (SettingsStore or a JsonStore); `key` is the
// dotted path. Rows for keys missing from Defaults.js hide themselves.
Item {
    id: root

    default property alias editor: editorSlot.data
    property var store: SettingsStore
    property string key: ""
    property string label: ""
    property string description: ""
    property string filterText: ""
    property bool stacked: false
    property bool separator: true
    property int editorWidth: 0
    property bool activatesLabel: false
    property bool filterHidden: false

    signal labelActivated()

    readonly property var current: {
        void store.generation;
        return key === "" ? undefined : store.get(key, undefined);
    }

    readonly property var baselineValue: {
        void store.generation;
        if (key === "" || store !== SettingsStore)
            return undefined;
        return Config.baseline(key);
    }

    readonly property bool canReset: key !== "" && store === SettingsStore && baselineValue !== undefined && !valuesEqual(current, baselineValue)

    function valuesEqual(a, b): bool {
        if (a === b)
            return true;
        if (typeof a === "number" && typeof b === "number")
            return Math.abs(a - b) < 1e-6;
        return JSON.stringify(a) === JSON.stringify(b);
    }

    function write(value: var): void {
        if (key !== "")
            store.set(key, value);
    }

    function reset(): void {
        if (canReset)
            write(baselineValue);
    }

    visible: key === "" || store.has(key)
    width: parent ? parent.width : implicitWidth
    implicitWidth: 400
    implicitHeight: (stacked ? labels.implicitHeight + Theme.spaceSm + editorSlot.implicitHeight : Math.max(labels.implicitHeight, editorSlot.implicitHeight, resetBtn.visible ? resetBtn.implicitHeight : 0, 32)) + Theme.spaceSm * 2 + 2

    states: State {
        name: "filtered"
        when: root.filterHidden
        PropertyChanges {
            root.visible: false
            root.height: 0
            root.enabled: false
        }
    }

    Column {
        id: labels
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Theme.spaceSm
        width: Math.max(0, (root.stacked ? parent.width : parent.width - editorSlot.width - Theme.spaceLg) - (resetBtn.visible ? resetBtn.width + Theme.spaceXs : 0))
        spacing: 2

        GlyphText {
            text: root.label
            width: parent.width
        }

        GlyphText {
            visible: root.description !== ""
            text: root.description
            role: "small"
            dim: true
            width: parent.width
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }

        TapHandler {
            enabled: root.activatesLabel
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onTapped: root.labelActivated()
        }
    }

    HexButton {
        id: resetBtn
        visible: root.canReset
        icon: "restart_alt"
        flat: true
        padding: Theme.spaceXs
        iconSize: Theme.sizeBody
        tooltip: "Reset"
        anchors.right: root.stacked ? parent.right : editorSlot.left
        anchors.rightMargin: Theme.spaceXs
        anchors.top: root.stacked ? parent.top : undefined
        anchors.topMargin: root.stacked ? Theme.spaceSm : 0
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        onClicked: root.reset()
    }

    Item {
        id: editorSlot
        anchors.right: parent.right
        anchors.left: root.stacked ? parent.left : undefined
        anchors.top: root.stacked ? labels.bottom : undefined
        anchors.topMargin: Theme.spaceSm
        anchors.verticalCenter: root.stacked ? undefined : parent.verticalCenter
        width: root.stacked ? parent.width : (root.editorWidth > 0 ? root.editorWidth : implicitWidth)
        height: implicitHeight
        implicitWidth: {
            let w = 0;
            for (const c of children)
                if (c.visible !== false)
                    w = Math.max(w, c.implicitWidth);
            return w;
        }
        implicitHeight: {
            let h = 0;
            for (const c of children)
                if (c.visible !== false)
                    h = Math.max(h, c.implicitHeight);
            return h;
        }
    }

    Rectangle {
        visible: root.separator && !root.filterHidden
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.alpha(Theme.lineDim, 0.4)
    }
}
