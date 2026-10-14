import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

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
    property bool stacked: false
    property bool separator: true
    property int editorWidth: 0

    readonly property var current: {
        void store.generation;
        return key === "" ? undefined : store.get(key, undefined);
    }

    function write(value: var): void {
        if (key !== "")
            store.set(key, value);
    }

    visible: key === "" || store.has(key)
    width: parent ? parent.width : implicitWidth
    implicitWidth: 400
    implicitHeight: (stacked ? labels.implicitHeight + Theme.spaceSm + editorSlot.implicitHeight : Math.max(labels.implicitHeight, editorSlot.implicitHeight, 30)) + Theme.spaceSm * 2 + 2

    Column {
        id: labels
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: Theme.spaceSm
        width: root.stacked ? parent.width : parent.width - editorSlot.width - Theme.spaceLg
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
        visible: root.separator
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.alpha(Theme.lineDim, 0.4)
    }
}
