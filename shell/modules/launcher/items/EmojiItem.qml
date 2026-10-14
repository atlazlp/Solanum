import QtQuick
import qs.theme
import qs.components

// One emoji cell: a HexButton with a 22 px colour-emoji glyph; tooltip = name.
HexButton {
    id: root

    required property var modelData
    required property int index
    property real cell: 48

    width: cell
    height: cell
    flat: true
    tooltip: modelData?.n ?? ""

    Text {
        anchors.centerIn: parent
        text: root.modelData?.e ?? ""
        font.family: "Noto Color Emoji"
        font.pixelSize: 22
        renderType: Text.NativeRendering
    }
}
