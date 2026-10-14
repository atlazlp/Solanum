import QtQuick
import qs.theme

// Scrollable column of rows / section headers. Children go in the column; it is as wide as the pane
// minus the scrollbar gutter.
Flickable {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + Theme.spaceLg
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    Column {
        id: column
        width: root.width - Theme.spaceLg
        spacing: 0
    }

    // Scroll indicator: a 2 px line in the right gutter.
    Rectangle {
        visible: root.contentHeight > root.height
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 2
        y: root.height * root.visibleArea.yPosition
        height: Math.max(16, root.height * root.visibleArea.heightRatio)
        color: Theme.alpha(Theme.line, 0.6)
    }
}
