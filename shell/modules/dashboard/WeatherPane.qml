pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// compact: icon / temperature / description summary for the Dash tab.
// full: current conditions + 7-day forecast + hourly strip (Weather tab).
GlyphReveal {
    id: root

    property bool compact: true

    autoTrigger: false
    implicitWidth: compact ? summary.implicitWidth : full.implicitWidth
    implicitHeight: compact ? summary.implicitHeight : full.implicitHeight

    function trigger(): void {
        // GlyphReveal.trigger staggers direct children; both layouts live here, only one visible.
        const kids = compact ? [summary] : full.children;
        for (const a of _anims)
            a.destroy();
        _anims = [];
        for (let i = 0; i < kids.length; i++) {
            if (kids[i].visible === false)
                continue;
            const anim = animProto.createObject(root, { target: kids[i], delay: Math.min(i, Motion.glyphStaggerMax) * Motion.glyphStagger });
            _anims.push(anim);
            anim.start();
        }
    }

    Component {
        id: animProto
        SequentialAnimation {
            id: seq
            required property Item target
            property int delay: 0
            property Translate tr: Translate { x: Motion.panelTranslate }
            Component.onCompleted: {
                target.opacity = 0;
                target.transform = [tr];
            }
            PauseAnimation { duration: seq.delay }
            ParallelAnimation {
                NumberAnimation { target: seq.target; property: "opacity"; from: 0; to: 1; duration: Motion.panelOpen; easing.type: Motion.enter }
                NumberAnimation { target: seq.tr; property: "x"; from: Motion.panelTranslate; to: 0; duration: Motion.panelOpen; easing.type: Motion.slide }
            }
        }
    }

    // ---- compact summary ----
    Column {
        id: summary

        visible: root.compact
        spacing: Theme.spaceSm

        SectionHeader {
            text: Weather.city ? `Weather · ${Weather.city}` : "Weather"
        }

        Row {
            spacing: Theme.spaceMd

            GlyphIcon {
                icon: Weather.icon
                size: 44
                color: Theme.line
                fill: 1
                anchors.verticalCenter: parent.verticalCenter
                animate: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                GlyphText {
                    role: "title"
                    text: Weather.temp
                    color: Theme.text
                    font.pointSize: 21
                }

                GlyphText {
                    role: "small"
                    text: Weather.hasData ? Weather.description : (Weather.loading ? "Loading..." : (Weather.error || "No data"))
                    dim: true
                }
            }
        }

        Row {
            spacing: Theme.spaceMd
            visible: Weather.hasData

            Repeater {
                model: [
                    { icon: "thermostat", text: Weather.feelsLike },
                    { icon: "humidity_percentage", text: `${Weather.humidity}%` },
                    { icon: "air", text: `${Math.round(Weather.windSpeed)} km/h` }
                ]
                Row {
                    required property var modelData
                    spacing: 3
                    GlyphIcon { icon: parent.modelData.icon; size: Theme.sizeSmall + 2; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    GlyphText { role: "small"; text: parent.modelData.text; dim: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // ---- full tab ----
    Column {
        id: full

        visible: !root.compact
        spacing: Theme.spaceMd
        width: 640

        // Header: now
        Item {
            width: parent.width
            implicitHeight: nowRow.implicitHeight

            Row {
                id: nowRow
                spacing: Theme.spaceLg

                GlyphIcon {
                    icon: Weather.icon
                    size: 64
                    color: Theme.line
                    fill: 1
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    GlyphText { role: "display"; text: Weather.temp; font.pointSize: 30; color: Theme.text }
                    GlyphText { role: "body"; text: Weather.hasData ? `${Weather.description} · feels like ${Weather.feelsLike}` : (Weather.loading ? "Loading..." : (Weather.error || "No data")); dim: true }
                }
            }

            Column {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                GlyphText { role: "label"; text: Weather.city || "Unknown location"; color: Theme.line; anchors.right: parent.right }
                Row {
                    anchors.right: parent.right
                    spacing: Theme.spaceMd
                    Repeater {
                        model: [
                            { icon: "wb_twilight", text: Weather.sunrise },
                            { icon: "wb_sunny", text: Weather.sunset },
                            { icon: "humidity_percentage", text: `${Weather.humidity}%` },
                            { icon: "air", text: `${Math.round(Weather.windSpeed)} km/h` }
                        ]
                        Row {
                            required property var modelData
                            spacing: 3
                            GlyphIcon { icon: parent.modelData.icon; size: Theme.sizeSmall + 3; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                            GlyphText { role: "small"; text: parent.modelData.text; dim: true; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                HexButton {
                    anchors.right: parent.right
                    icon: "refresh"
                    text: Weather.loading ? "Loading" : "Refresh"
                    flat: true
                    padding: Theme.spaceXs
                    iconSize: Theme.sizeSmall + 3
                    enabled: !Weather.loading
                    onClicked: Weather.reload()
                }
            }
        }

        SectionHeader { text: "7 days" }

        Row {
            width: parent.width
            spacing: Theme.spaceSm

            Repeater {
                model: Weather.forecast

                NomaiFrame {
                    id: dayCard

                    required property var modelData
                    required property int index

                    width: (full.width - Theme.spaceSm * 6) / 7
                    padding: Theme.spaceSm
                    chamfer: Theme.chamferSm
                    fill: index === 0 ? Theme.alpha(Theme.line, 0.1) : Theme.ink1
                    lineOpacity: index === 0 ? 1 : 0.4
                    glow: index === 0

                    Column {
                        width: dayCard.width - dayCard.padding * 2
                        spacing: 2
                        GlyphText { anchors.horizontalCenter: parent.horizontalCenter; role: "label"; text: dayCard.index === 0 ? "Today" : dayCard.modelData.day; color: dayCard.index === 0 ? Theme.line : Theme.textDim }
                        GlyphIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: dayCard.modelData.icon; size: 26; color: Theme.line; fill: 1 }
                        GlyphText { anchors.horizontalCenter: parent.horizontalCenter; role: "body"; text: Weather.tempFor(dayCard.modelData.maxTempC, dayCard.modelData.maxTempF); color: Theme.text }
                        GlyphText { anchors.horizontalCenter: parent.horizontalCenter; role: "small"; text: Weather.tempFor(dayCard.modelData.minTempC, dayCard.modelData.minTempF); dim: true }
                    }
                }
            }
        }

        SectionHeader { text: "Hourly" }

        Flickable {
            width: parent.width
            height: hourRow.implicitHeight
            contentWidth: hourRow.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: hourRow
                spacing: Theme.spaceSm

                Repeater {
                    model: Weather.hourlyForecast

                    Column {
                        id: hour
                        required property var modelData
                        required property int index
                        width: 46
                        spacing: 2
                        GlyphText { anchors.horizontalCenter: parent.horizontalCenter; role: "label"; font.letterSpacing: 0; text: hour.index === 0 ? "Now" : hour.modelData.label; color: hour.index === 0 ? Theme.line : Theme.textDim }
                        GlyphIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: hour.modelData.icon; size: 20; color: Theme.line }
                        GlyphText { anchors.horizontalCenter: parent.horizontalCenter; role: "small"; text: Weather.tempFor(hour.modelData.tempC, hour.modelData.tempF); color: Theme.text }
                    }
                }
            }

            WheelHandler {
                onWheel: event => parent.contentX = Math.max(0, Math.min(parent.contentWidth - parent.width, parent.contentX - event.angleDelta.y))
            }
        }
    }
}
