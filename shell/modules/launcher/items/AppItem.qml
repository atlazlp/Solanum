import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

// Launcher app row: icon (override aware), label, subtitle, favourite pip, hover edit button.
RowBase {
    id: root

    signal launchRequested(var app)
    signal editRequested(var target)

    readonly property string appKey: modelData?.id ?? ""
    readonly property string defaultIcon: Quickshell.iconPath(modelData?.icon ?? "", true)
    readonly property string defaultLabel: modelData?.name ?? ""
    readonly property string defaultSubtitle: (modelData?.comment || modelData?.genericName || modelData?.name) ?? ""
    readonly property bool showActions: rowHovered || editBtn.hovered

    function editTarget(): var {
        return {
            type: "app",
            key: appKey,
            defaultLabel: defaultLabel,
            defaultSubtitle: defaultSubtitle,
            defaultIcon: defaultIcon
        };
    }

    onActivated: launchRequested(modelData)
    onRightClicked: editRequested(editTarget())

    IconImage {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Math.round(root.height * 0.62)
        asynchronous: true
        source: LauncherItemOverrides.iconSource("app", root.appKey, root.defaultIcon)
        visible: source.toString() !== ""
    }

    GlyphIcon {
        anchors.centerIn: icon
        visible: !icon.visible
        icon: "apps"
        color: Theme.textDim
    }

    Column {
        anchors.left: icon.right
        anchors.leftMargin: Theme.spaceMd
        anchors.right: trailing.left
        anchors.rightMargin: Theme.spaceSm
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        GlyphText {
            width: parent.width
            text: LauncherItemOverrides.displayLabel("app", root.appKey, root.defaultLabel)
            role: "body"
            elide: Text.ElideRight
            color: root.current ? Theme.line : Theme.text
        }

        GlyphText {
            width: parent.width
            text: LauncherItemOverrides.subtitle("app", root.appKey, root.defaultSubtitle)
            role: "small"
            dim: true
            elide: Text.ElideRight
            visible: text !== ""
        }
    }

    Row {
        id: trailing
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceSm

        GlyphIcon {
            visible: root.modelData?.favourite ?? false
            icon: "star"
            fill: 1
            size: Theme.sizeIcon * 0.8
            color: Theme.ember
            anchors.verticalCenter: parent.verticalCenter
        }

        GlyphIcon {
            visible: LauncherItemOverrides.hasOverride("app", root.appKey)
            icon: "edit_note"
            size: Theme.sizeIcon * 0.8
            color: Theme.textDim
            anchors.verticalCenter: parent.verticalCenter
        }

        HexButton {
            id: editBtn
            flat: true
            icon: "edit"
            iconSize: Theme.sizeIcon * 0.85
            padding: Theme.spaceXs
            tooltip: "Edit (F2)"
            opacity: root.showActions ? 1 : 0
            visible: opacity > 0
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.editRequested(root.editTarget())
            Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        }
    }
}
