import QtQuick
import qs.theme
import qs.components
import qs.services

// Clipboard row: image thumbnail (lazily decoded) or 2-line mono preview; hover pin + delete.
RowBase {
    id: root

    signal copyRequested(var entry)
    signal pinToggled(var entry)
    signal deleteRequested(var entry)

    readonly property bool isImage: modelData?.isImage ?? false
    readonly property string imagePath: modelData?.imagePath ?? ""
    readonly property bool showActions: rowHovered || pinBtn.hovered || delBtn.hovered

    onActivated: copyRequested(modelData)
    onRightClicked: pinToggled(modelData)

    Component.onCompleted: {
        if (isImage && !imagePath)
            Clipboard.ensureImage(modelData.id);
    }

    NomaiFrame {
        id: thumb
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(root.height * 0.8)
        height: width
        padding: 2
        chamfer: Theme.chamferSm
        fill: Theme.ink0
        lineOpacity: 0.4

        Image {
            anchors.fill: parent
            visible: root.isImage && root.imagePath !== ""
            source: root.imagePath ? `file://${root.imagePath}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 96
            sourceSize.height: 96
        }

        GlyphIcon {
            anchors.centerIn: parent
            visible: !root.isImage || root.imagePath === ""
            icon: root.isImage ? "image" : "notes"
            size: Theme.sizeIcon * 0.9
            color: Theme.textDim
        }
    }

    GlyphText {
        anchors.left: thumb.right
        anchors.leftMargin: Theme.spaceMd
        anchors.right: trailing.left
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        text: root.modelData?.preview ?? ""
        role: "mono"
        textFormat: Text.PlainText
        color: root.current ? Theme.line : Theme.text
        wrapMode: Text.WrapAnywhere
        maximumLineCount: 2
        elide: Text.ElideRight
        lineHeight: 0.95
    }

    Row {
        id: trailing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceSm

        HexButton {
            id: pinBtn
            flat: !(root.modelData?.pinned ?? false)
            active: root.modelData?.pinned ?? false
            icon: "keep"
            iconFill: active ? 1 : 0
            iconSize: Theme.sizeIcon * 0.85
            padding: Theme.spaceXs
            tooltip: active ? "Unpin" : "Pin"
            opacity: root.showActions || active ? 1 : 0
            visible: opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.pinToggled(root.modelData)
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }

        HexButton {
            id: delBtn
            flat: true
            danger: true
            icon: "delete"
            iconSize: Theme.sizeIcon * 0.85
            padding: Theme.spaceXs
            tooltip: "Delete"
            opacity: root.showActions ? 1 : 0
            visible: opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.deleteRequested(root.modelData)
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
    }
}
