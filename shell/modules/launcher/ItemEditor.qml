import QtQuick
import Quickshell.Widgets
import qs.config
import qs.theme
import qs.components
import qs.services

// Override editor for a launcher app / window row: label, subtitle and an icon file path.
// Enter saves, Esc cancels. Writes through LauncherItemOverrides.
Modal {
    id: root

    property var target: null       // { type, key, defaultLabel, defaultSubtitle, defaultIcon }

    signal closed()

    open: target !== null && target !== undefined
    title: target?.type === "window" ? "Edit window" : "Edit app"

    readonly property bool hasOverride: target ? LauncherItemOverrides.hasOverride(target.type, target.key) : false

    function edit(t: var): void {
        target = t;
        const e = LauncherItemOverrides.entry(t.type, t.key);
        labelField.text = e?.label ?? "";
        subtitleField.text = e?.subtitle ?? "";
        iconField.text = "";
        Qt.callLater(() => labelField.forceFocus());
    }

    function save(): void {
        if (!target)
            return;
        LauncherItemOverrides.saveOverride(target.type, target.key, labelField.text, subtitleField.text, iconField.text);
        finish();
    }

    function reset(): void {
        if (!target)
            return;
        LauncherItemOverrides.resetOverride(target.type, target.key);
        finish();
    }

    function finish(): void {
        target = null;
        closed();
    }

    onDismissed: finish()

    Column {
        id: col
        width: 420
        spacing: Theme.spaceMd

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.finish();
                event.accepted = true;
            }
        }

        Row {
            spacing: Theme.spaceMd
            width: parent.width

            NomaiFrame {
                width: 56
                height: 56
                padding: 4
                fill: Theme.ink0
                chamfer: Theme.chamferSm
                anchors.verticalCenter: parent.verticalCenter

                IconImage {
                    anchors.fill: parent
                    asynchronous: true
                    source: {
                        const typed = iconField.text.trim();
                        if (typed)
                            return `file://${Paths.expand(typed)}`;
                        return root.target ? LauncherItemOverrides.iconSource(root.target.type, root.target.key, root.target.defaultIcon ?? "") : "";
                    }
                }
            }

            Column {
                width: parent.width - 56 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                GlyphText {
                    width: parent.width
                    text: root.target?.defaultLabel ?? ""
                    role: "large"
                    elide: Text.ElideRight
                }
                GlyphText {
                    width: parent.width
                    text: root.target?.key ?? ""
                    role: "mono"
                    dim: true
                    elide: Text.ElideMiddle
                }
            }
        }

        NomaiDivider {
            segments: 5
        }

        Field {
            label: "Label"
            field: labelField
            NomaiTextField {
                id: labelField
                width: parent.width
                placeholder: root.target?.defaultLabel ?? ""
                onAccepted: root.save()
                onEscaped: root.finish()
            }
        }

        Field {
            label: "Subtitle"
            field: subtitleField
            NomaiTextField {
                id: subtitleField
                width: parent.width
                placeholder: root.target?.defaultSubtitle ?? ""
                onAccepted: root.save()
                onEscaped: root.finish()
            }
        }

        Field {
            label: "Icon file"
            field: iconField
            NomaiTextField {
                id: iconField
                width: parent.width
                icon: "image"
                placeholder: "/path/to/icon.png (leave empty to keep)"
                onAccepted: root.save()
                onEscaped: root.finish()
            }
        }

        Row {
            spacing: Theme.spaceSm
            anchors.right: parent.right

            HexButton {
                visible: root.hasOverride
                text: "Reset"
                icon: "restart_alt"
                danger: true
                onClicked: root.reset()
            }

            HexButton {
                text: "Cancel"
                icon: "close"
                onClicked: root.finish()
            }

            HexButton {
                text: "Save"
                icon: "check"
                glow: true
                onClicked: root.save()
            }
        }
    }

    component Field: Column {
        property string label: ""
        property var field: null
        default property alias content: body.data
        width: parent.width
        spacing: Theme.spaceXs

        GlyphText {
            text: parent.label
            role: "label"
            dim: true
        }

        Item {
            id: body
            width: parent.width
            implicitHeight: childrenRect.height
            height: implicitHeight
        }
    }
}
