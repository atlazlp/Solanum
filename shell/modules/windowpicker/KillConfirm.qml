import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

// "Kill this window?" dialog. Enter / Y confirm (killwindow + kill -TERM pid), N / C / Esc cancel.
Modal {
    id: root

    property var target: null

    signal confirmed(var row)
    signal cancelled()

    open: target !== null && target !== undefined
    title: "Kill window"

    function ask(row: var): void {
        target = row;
        Qt.callLater(() => scope.forceActiveFocus());
    }

    function confirm(): void {
        const row = target;
        if (!row)
            return;
        const addr = (row.address ?? "").toString().trim();
        const pid = row.pid ?? 0;
        if (addr)
            Hypr.dispatch(`killwindow address:${addr}`);
        if (pid > 0)
            Quickshell.execDetached(["kill", "-TERM", String(pid)]);
        target = null;
        confirmed(row);
    }

    function cancel(): void {
        if (!target)
            return;
        target = null;
        cancelled();
    }

    onDismissed: cancel()

    FocusScope {
        id: scope
        implicitWidth: col.implicitWidth
        implicitHeight: col.implicitHeight
        focus: true

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Y:
                root.confirm();
                event.accepted = true;
                break;
            case Qt.Key_N:
            case Qt.Key_C:
            case Qt.Key_Escape:
                root.cancel();
                event.accepted = true;
                break;
            }
        }

        Column {
            id: col
            spacing: Theme.spaceMd
            width: 360

            Row {
                spacing: Theme.spaceMd
                width: parent.width

                GlyphIcon {
                    icon: "warning"
                    size: Theme.sizeIcon * 1.6
                    color: Theme.danger
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    width: parent.width - Theme.sizeIcon * 1.6 - parent.spacing
                    spacing: 2
                    GlyphText {
                        width: parent.width
                        text: root.target?.line ?? ""
                        role: "large"
                        elide: Text.ElideRight
                    }
                    GlyphText {
                        width: parent.width
                        text: {
                            const pid = root.target?.pid ?? 0;
                            const k = root.target?.klass ?? "";
                            return pid > 0 ? `${k}  ·  PID ${pid}` : k;
                        }
                        role: "small"
                        dim: true
                        elide: Text.ElideRight
                    }
                }
            }

            GlyphText {
                text: "Enter or Y to kill  ·  N, C or Esc to cancel"
                role: "label"
                dim: true
            }

            Row {
                spacing: Theme.spaceSm
                anchors.right: parent.right

                HexButton {
                    text: "Cancel"
                    icon: "close"
                    onClicked: root.cancel()
                }

                HexButton {
                    text: "Kill"
                    icon: "skull"
                    danger: true
                    glow: true
                    onClicked: root.confirm()
                }
            }
        }
    }
}
