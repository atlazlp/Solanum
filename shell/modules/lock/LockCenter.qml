import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import qs.config
import qs.theme
import qs.components
import qs.services
import "../../theme/Glyphs.js" as Glyphs

// Centre column: display clock, date, hex-masked avatar (~/.face), password field (hex pips),
// PAM / fingerprint / caps-lock messages. Keys are handled by the surface; this only renders Pam.
Item {
    id: root

    required property var pam

    readonly property int fieldWidth: Math.min(340, width)
    readonly property bool fprintMaxed: pam.fprint.available && pam.fprint.tries >= pam.maxFprintTries

    readonly property string message: {
        const p = root.pam;
        if (p.fprintState === "error")
            return `Fingerprint error: ${p.fprint.message}`;
        if (p.state === "error")
            return `Error: ${p.passwd.message}`;
        if (p.lockMessage)
            return p.lockMessage;
        if (p.state === "max" && p.fprintState === "max")
            return "Maximum password and fingerprint attempts reached.";
        if (p.state === "max")
            return p.fprint.available ? "Maximum password attempts reached. Use fingerprint." : "Maximum password attempts reached.";
        if (p.fprintState === "max")
            return "Maximum fingerprint attempts reached. Use password.";
        if (p.state === "fail")
            return p.fprint.available ? "Incorrect password. Try again or use fingerprint." : "Incorrect password. Try again.";
        if (p.fprintState === "fail")
            return `Fingerprint not recognised (${p.fprint.tries}/${p.maxFprintTries}).`;
        return "";
    }

    readonly property string hint: {
        const parts = [];
        if (Hypr.capsLock)
            parts.push("Caps lock is on");
        if (Hypr.numLock && false)
            parts.push("Num lock is on");
        if (root.pam.fprint.active)
            parts.push("Touch the fingerprint reader or type your password");
        return parts.join(" · ");
    }

    Connections {
        target: root.pam

        function onFailed(): void {
            shake.restart();
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.spaceMd

        GlyphText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("HH:mm")
            role: "display"
            font.pointSize: 72
            font.letterSpacing: 4
            color: Theme.line
            style: Text.Normal
        }

        GlyphText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Time.format("dddd, d MMMM yyyy")
            role: "mono"
            dim: true
            font.letterSpacing: 1
        }

        Item {
            width: 1
            height: Theme.spaceMd
        }

        // Avatar in a hex mask; falls back to a person glyph.
        Item {
            id: avatar

            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 96

            Image {
                id: face

                anchors.fill: parent
                source: `file://${Quickshell.env("HOME")}/.face`
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(192, 192)
                asynchronous: true
                visible: false
                layer.enabled: true
            }

            Shape {
                id: hexMask

                anchors.fill: parent
                visible: false
                layer.enabled: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "black"
                    strokeColor: "transparent"
                    PathSvg { path: Glyphs.hexagon(hexMask.width, hexMask.height, undefined, 2) }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: face
                maskEnabled: true
                maskSource: hexMask
                visible: face.status === Image.Ready
            }

            NomaiFrame {
                anchors.fill: parent
                shape: "hex"
                fill: face.status === Image.Ready ? "transparent" : Theme.ink2
                lineColor: Theme.line
                lineOpacity: 0.8
                glow: true

                GlyphIcon {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    icon: "person"
                    size: 40
                    color: Theme.textDim
                }
            }
        }

        Item {
            width: 1
            height: Theme.spaceSm
        }

        // Password field
        NomaiFrame {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.fieldWidth
            height: 46
            padding: Theme.spaceSm
            chamfer: Theme.chamferMd
            fill: Theme.ink1
            lineColor: root.pam.state === "fail" || root.pam.state === "max" || root.pam.state === "error" ? Theme.danger : Theme.line
            lineOpacity: root.pam.buffer.length > 0 || root.pam.busy ? 1 : 0.55
            glow: root.pam.buffer.length > 0

            transform: Translate { id: shakeTr }

            GlyphIcon {
                id: leftIcon

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spaceXs
                icon: root.fprintMaxed ? "fingerprint_off" : (root.pam.fprint.active ? "fingerprint" : "lock")
                color: root.fprintMaxed ? Theme.danger : Theme.textDim
                animate: true
                size: 18
            }

            Item {
                id: entry

                anchors.left: leftIcon.right
                anchors.right: eye.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: Theme.spaceSm
                anchors.rightMargin: Theme.spaceSm
                clip: true

                GlyphText {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    role: "mono"
                    dim: true
                    text: root.pam.busy ? "Authenticating…" : (root.pam.state === "max" ? "Locked out" : "Enter password")
                    opacity: root.pam.buffer.length === 0 || root.pam.busy ? 1 : 0
                    color: root.pam.busy ? Theme.line : Theme.textDim

                    Behavior on opacity {
                        NumberAnimation { duration: Motion.fast; easing.type: Motion.fade }
                    }
                }

                // Hidden: one small hex pip per character.
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    visible: !root.pam.showPassword && !root.pam.busy

                    Repeater {
                        model: Math.min(root.pam.buffer.length, 40)

                        Shape {
                            width: 10
                            height: 10
                            preferredRendererType: Shape.CurveRenderer
                            scale: 1

                            ShapePath {
                                fillColor: Theme.text
                                strokeColor: "transparent"
                                PathSvg { path: Glyphs.hexPip(5, 5, 4.5) }
                            }

                            Component.onCompleted: {
                                scale = 0.4;
                                scale = 1;
                            }

                            Behavior on scale {
                                NumberAnimation { duration: Motion.fast; easing.type: Motion.enter }
                            }
                        }
                    }
                }

                // Shown (Ctrl+H or the eye button).
                GlyphText {
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    role: "mono"
                    text: root.pam.buffer
                    visible: root.pam.showPassword && !root.pam.busy && root.pam.buffer.length > 0
                }
            }

            HexButton {
                id: eye

                anchors.right: submit.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: Theme.spaceXs
                flat: true
                icon: root.pam.showPassword ? "visibility_off" : "visibility"
                iconSize: 16
                padding: 5
                tooltip: ""
                onClicked: root.pam.showPassword = !root.pam.showPassword
            }

            HexButton {
                id: submit

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                flat: root.pam.buffer.length === 0
                active: root.pam.buffer.length > 0
                icon: "arrow_forward"
                iconSize: 16
                padding: 5
                onClicked: root.pam.submit()
            }

            // Thin busy line along the bottom edge while PAM runs.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                height: 1
                width: parent.width * 0.3
                color: Theme.line
                visible: root.pam.busy
                x: 0

                SequentialAnimation on x {
                    running: root.pam.busy
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: field.width * 0.7; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: field.width * 0.7; to: 0; duration: 600; easing.type: Easing.InOutQuad }
                }
            }
        }

        GlyphText {
            id: messageText

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.fieldWidth
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            elide: Text.ElideNone
            role: "small"
            color: Theme.danger
            text: root.message
            visible: text !== ""
            opacity: 1

            Connections {
                target: root.pam

                function onFlashMsg(): void {
                    flash.restart();
                }
            }

            SequentialAnimation {
                id: flash

                loops: 2
                NumberAnimation { target: messageText; property: "opacity"; to: 0.3; duration: Motion.fast }
                NumberAnimation { target: messageText; property: "opacity"; to: 1; duration: Motion.fast }
            }
        }

        GlyphText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.fieldWidth
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            elide: Text.ElideNone
            role: "small"
            dim: true
            text: root.hint
            visible: text !== ""
        }
    }

    SequentialAnimation {
        id: shake

        NumberAnimation { target: shakeTr; property: "x"; to: -10; duration: 40 }
        NumberAnimation { target: shakeTr; property: "x"; to: 10; duration: 60 }
        NumberAnimation { target: shakeTr; property: "x"; to: -7; duration: 60 }
        NumberAnimation { target: shakeTr; property: "x"; to: 7; duration: 60 }
        NumberAnimation { target: shakeTr; property: "x"; to: 0; duration: 50 }
    }
}
