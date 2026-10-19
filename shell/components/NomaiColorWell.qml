pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import "../theme/Colour.js" as Colour

// Palette swatch. Click opens a hue / saturation / value plane and a hex field.
Item {
    id: root

    property color value: "#000000"
    property string name: ""
    property bool fixed: false
    property bool overridden: false
    property bool adjusting: false
    property real hue: 0
    property real sat: 0
    property real val: 0
    property string hexError: ""
    property var popup: null
    readonly property bool open: popup !== null

    signal picked(color value)
    signal cleared()

    implicitWidth: 104
    implicitHeight: column.implicitHeight
    activeFocusOnTab: true

    function syncFromValue(): void {
        const hsv = Colour.toHsv(root.value.r, root.value.g, root.value.b);
        root.hue = hsv.h;
        root.sat = hsv.s;
        root.val = hsv.v;
    }

    function currentColor(): color {
        const rgb = Colour.fromHsv(root.hue, root.sat, root.val);
        return Qt.rgba(rgb.r, rgb.g, rgb.b, 1);
    }

    function emitPicked(): void {
        root.picked(root.currentColor());
    }

    function hexText(): string {
        const c = root.currentColor();
        return Colour.plainHex(c.r, c.g, c.b);
    }

    function applyHex(t: string): void {
        const m = String(t).trim().replace("#", "");
        if (!/^[0-9a-fA-F]{6}$/.test(m)) {
            root.hexError = "Use a 6-digit hex colour";
            return;
        }
        root.hexError = "";
        const rgb = {
            r: parseInt(m.slice(0, 2), 16) / 255,
            g: parseInt(m.slice(2, 4), 16) / 255,
            b: parseInt(m.slice(4, 6), 16) / 255
        };
        const hsv = Colour.toHsv(rgb.r, rgb.g, rgb.b);
        root.hue = hsv.h;
        root.sat = hsv.s;
        root.val = hsv.v;
        root.emitPicked();
    }

    function overlayItem(): Item {
        let p = root;
        while (p.parent)
            p = p.parent;
        return p;
    }

    function openPopup(): void {
        if (root.popup)
            return;
        root.syncFromValue();
        root.hexError = "";
        const host = overlayItem();
        const w = 240;
        const h = 312;
        const pos = root.mapToItem(host, 0, column.implicitHeight + Theme.spaceXs);
        root.popup = popupComp.createObject(host, {
            x: Math.max(0, Math.min(pos.x, host.width - w)),
            y: pos.y + h > host.height ? Math.max(0, root.mapToItem(host, 0, 0).y - h - Theme.spaceXs) : pos.y,
            width: w,
            height: h
        });
        root.popup.forceActiveFocus();
    }

    function close(): void {
        if (!root.popup)
            return;
        const hadFocus = root.popup.activeFocus;
        root.popup.destroy();
        root.popup = null;
        if (hadFocus)
            root.forceActiveFocus();
    }

    function toggle(): void {
        if (root.open)
            close();
        else
            openPopup();
    }

    onValueChanged: {
        if (!root.adjusting)
            root.syncFromValue();
    }
    Component.onCompleted: syncFromValue()
    Component.onDestruction: close()
    onVisibleChanged: if (!visible) close()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.toggle();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && root.open) {
            root.close();
            event.accepted = true;
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: 2

        NomaiFrame {
            id: swatch
            width: 92
            height: 40
            padding: 0
            chamfer: Theme.chamferSm
            fill: root.value
            lineColor: root.activeFocus || swatchHover.hovered || root.open ? Theme.line : Theme.lineDim
            lineOpacity: 0.9
            glow: root.activeFocus || root.open

            HoverHandler {
                id: swatchHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.toggle()
            }
        }

        GlyphText {
            text: root.name
            role: "small"
        }

        GlyphText {
            text: "#" + Colour.plainHex(root.value.r, root.value.g, root.value.b)
            role: "mono"
            dim: true
            font.pointSize: Theme.sizeLabel
        }

        Item {
            width: 92
            height: 18

            GlyphText {
                visible: root.fixed && !root.overridden
                text: "fixed"
                role: "small"
                dim: true
                anchors.verticalCenter: parent.verticalCenter
            }

            HexButton {
                visible: root.overridden
                icon: "restart_alt"
                flat: true
                padding: 0
                iconSize: Theme.sizeSmall
                tooltip: "Reset"
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.cleared()
            }
        }
    }

    Component {
        id: popupComp

        Item {
            id: pop

            z: Theme.zModal + 5
            focus: true

            Keys.onEscapePressed: root.close()

            Item {
                x: -pop.x
                y: -pop.y
                width: pop.parent ? pop.parent.width : 0
                height: pop.parent ? pop.parent.height : 0
                z: -1

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onTapped: root.close()
                }
            }

            NomaiFrame {
                anchors.fill: parent
                padding: Theme.spaceMd
                chamfer: Theme.chamferSm
                fill: Theme.ink1
                glow: true
                ticks: true

                Column {
                    anchors.fill: parent
                    spacing: Theme.spaceSm

                    Item {
                        id: plane
                        width: parent.width
                        height: 132

                        Canvas {
                            id: sv
                            anchors.fill: parent
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                if (!ctx)
                                    return;
                                ctx.clearRect(0, 0, width, height);
                                const horizontal = ctx.createLinearGradient(0, 0, width, 0);
                                horizontal.addColorStop(0, "#ffffff");
                                const pure = Colour.fromHsv(root.hue, 1, 1);
                                horizontal.addColorStop(1, "#" + Colour.plainHex(pure.r, pure.g, pure.b));
                                ctx.fillStyle = horizontal;
                                ctx.fillRect(0, 0, width, height);
                                const vertical = ctx.createLinearGradient(0, 0, 0, height);
                                vertical.addColorStop(0, "rgba(0,0,0,0)");
                                vertical.addColorStop(1, "#000000");
                                ctx.fillStyle = vertical;
                                ctx.fillRect(0, 0, width, height);
                            }
                            Component.onCompleted: requestPaint()

                            Connections {
                                target: root
                                function onHueChanged(): void {
                                    sv.requestPaint();
                                }
                            }
                        }

                        Rectangle {
                            width: 12
                            height: 12
                            x: Math.max(0, Math.min(parent.width - width, root.sat * parent.width - width / 2))
                            y: Math.max(0, Math.min(parent.height - height, (1 - root.val) * parent.height - height / 2))
                            color: "transparent"
                            border.width: 2
                            border.color: root.val > 0.55 ? "#111111" : "#f5f2ea"
                        }

                        function pickAt(px: real, py: real): void {
                            root.sat = Math.max(0, Math.min(1, px / width));
                            root.val = Math.max(0, Math.min(1, 1 - py / height));
                            root.hexError = "";
                            root.emitPicked();
                            sv.requestPaint();
                        }

                        DragHandler {
                            target: null
                            onActiveChanged: root.adjusting = active
                            onCentroidChanged: if (active) plane.pickAt(centroid.position.x, centroid.position.y)
                        }

                        TapHandler {
                            onTapped: point => plane.pickAt(point.position.x, point.position.y)
                        }
                    }

                    Item {
                        id: hueBar
                        width: parent.width
                        height: 16

                        Canvas {
                            id: hueCanvas
                            anchors.fill: parent
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d");
                                if (!ctx)
                                    return;
                                ctx.clearRect(0, 0, width, height);
                                const g = ctx.createLinearGradient(0, 0, width, 0);
                                for (let i = 0; i <= 6; i++) {
                                    const rgb = Colour.fromHsv(i * 60, 1, 1);
                                    g.addColorStop(i / 6, "#" + Colour.plainHex(rgb.r, rgb.g, rgb.b));
                                }
                                ctx.fillStyle = g;
                                ctx.fillRect(0, 0, width, height);
                            }
                            Component.onCompleted: requestPaint()
                        }

                        Rectangle {
                            width: 4
                            height: parent.height
                            x: Math.max(0, Math.min(parent.width - width, (root.hue / 360) * parent.width - width / 2))
                            color: "transparent"
                            border.width: 2
                            border.color: "#f5f2ea"
                        }

                        function pickHue(px: real): void {
                            root.hue = Math.max(0, Math.min(359.999, (px / width) * 360));
                            root.hexError = "";
                            root.emitPicked();
                            sv.requestPaint();
                        }

                        DragHandler {
                            target: null
                            onActiveChanged: root.adjusting = active
                            onCentroidChanged: if (active) hueBar.pickHue(centroid.position.x)
                        }

                        TapHandler {
                            onTapped: point => hueBar.pickHue(point.position.x)
                        }
                    }

                    NomaiTextField {
                        id: hexField
                        width: parent.width
                        placeholder: "RRGGBB"
                        input.font.family: Theme.fontMono
                        Component.onCompleted: text = root.hexText()

                        Connections {
                            target: root
                            function onHueChanged(): void {
                                if (!hexField.focused)
                                    hexField.text = root.hexText();
                            }
                            function onSatChanged(): void {
                                if (!hexField.focused)
                                    hexField.text = root.hexText();
                            }
                            function onValChanged(): void {
                                if (!hexField.focused)
                                    hexField.text = root.hexText();
                            }
                        }

                        onAccepted: root.applyHex(text)
                        onEscaped: {
                            text = root.hexText();
                            root.hexError = "";
                            input.focus = false;
                        }
                        input.onEditingFinished: {
                            if (text.trim().replace("#", "").toUpperCase() !== root.hexText())
                                root.applyHex(text);
                        }
                    }

                    GlyphText {
                        visible: root.hexError !== ""
                        text: root.hexError
                        role: "small"
                        color: Theme.danger
                        width: parent.width
                        wrapMode: Text.WordWrap
                    }

                    HexButton {
                        visible: root.overridden
                        icon: "restart_alt"
                        text: "Reset"
                        flat: true
                        onClicked: {
                            root.cleared();
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
