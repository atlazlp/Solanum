import QtQuick
import qs.theme
import qs.components

// `>` action row: glyph icon, name, description.
RowBase {
    id: root

    signal runRequested(var action)

    onActivated: runRequested(modelData)

    GlyphIcon {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        icon: root.modelData?.icon ?? "bolt"
        size: Theme.sizeIcon * 1.2
        color: root.current ? Theme.line : Theme.text
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceMd
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        GlyphText {
            width: parent.width
            text: root.modelData?.name ?? ""
            elide: Text.ElideRight
            color: root.current ? Theme.line : Theme.text
        }

        GlyphText {
            width: parent.width
            text: root.modelData?.description ?? ""
            role: "small"
            dim: true
            elide: Text.ElideRight
            visible: text !== ""
        }
    }
}
