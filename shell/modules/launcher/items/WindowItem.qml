import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Window row: app icon, cleaned title, class, RAM; hover reveals edit + kill.
// modelData: { address, pid, line, klass, subtitle, ramLabel, title, wsId, wsLabel, icon }
RowBase {
    id: root

    signal focusRequested(var row)
    signal killRequested(var row)
    signal editRequested(var target)

    readonly property bool isHeader: modelData?.header ?? false
    readonly property string klass: modelData?.klass ?? ""
    readonly property bool showActions: !isHeader && (rowHovered || editBtn.hovered || killBtn.hovered)

    implicitHeight: isHeader ? Theme.sizeLabel * 2 + Theme.spaceMd : (list?.rowHeight ?? 44)
    selectable: !isHeader

    function editTarget(): var {
        return {
            type: "window",
            key: klass,
            defaultLabel: modelData?.rawLine ?? "",
            defaultSubtitle: klass,
            defaultIcon: modelData?.icon ?? ""
        };
    }

    onActivated: if (!isHeader) focusRequested(modelData)
    onRightClicked: if (!isHeader) editRequested(editTarget())

    SectionHeader {
        visible: root.isHeader
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.modelData?.wsLabel ?? ""
    }

    IconImage {
        id: icon
        visible: !root.isHeader && source.toString() !== ""
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Math.round(root.list?.rowHeight * 0.62 ?? 27)
        asynchronous: true
        source: root.isHeader ? "" : LauncherItemOverrides.iconSource("window", root.klass, root.modelData?.icon ?? "")
    }

    GlyphIcon {
        anchors.centerIn: icon
        visible: !root.isHeader && !icon.visible
        icon: "select_window"
        color: Theme.textDim
    }

    Column {
        visible: !root.isHeader
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceMd
        anchors.right: trailing.left
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        GlyphText {
            width: parent.width
            text: root.modelData?.line ?? ""
            role: "body"
            elide: Text.ElideRight
            color: root.current ? Theme.line : Theme.text
        }

        GlyphText {
            width: parent.width
            text: root.modelData?.subtitle ?? ""
            role: "small"
            dim: true
            elide: Text.ElideRight
            visible: text !== ""
        }
    }

    Row {
        id: trailing
        visible: !root.isHeader
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceSm

        GlyphText {
            text: root.isHeader ? "" : (root.list?.ramLabelFor(root.modelData?.pid ?? 0) ?? "")
            role: "mono"
            dim: true
            visible: text !== ""
            anchors.verticalCenter: parent.verticalCenter
        }

        HexButton {
            id: editBtn
            flat: true
            icon: "edit"
            iconSize: Theme.sizeIcon * 0.85
            padding: Theme.spaceXs
            tooltip: "Edit"
            opacity: root.showActions ? 1 : 0
            visible: opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.editRequested(root.editTarget())
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }

        HexButton {
            id: killBtn
            flat: true
            danger: true
            icon: "close"
            iconSize: Theme.sizeIcon * 0.85
            padding: Theme.spaceXs
            tooltip: "Kill (Del)"
            opacity: root.showActions ? 1 : 0
            visible: opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.killRequested(root.modelData)
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
    }
}
