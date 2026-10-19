import QtQuick
import Quickshell.Io
import qs.config
import qs.theme
import qs.components
import qs.utils

// Current conditions + 3-day strip read from ~/.cache/solanum/weather.json (written by the
// Weather singleton); the lock never fetches on its own.
NomaiFrame {
    id: root

    property var cc: null
    property list<var> forecast: []
    property string city: ""
    readonly property bool fahrenheit: Config.dashboard?.weather?.useFahrenheit ?? false

    padding: Theme.spaceMd
    fill: Theme.alpha(Theme.ink2, 0.9)
    lineOpacity: 0.5
    corners: 1
    implicitHeight: 128

    function temp(c: var, f: var): string {
        if (c === undefined || c === null)
            return "--°";
        return root.fahrenheit ? `${f}°F` : `${c}°C`;
    }

    FileView {
        id: cache

        path: `${Paths.cache}/weather.json`
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.cc = j.cc ?? null;
                root.forecast = (j.forecast ?? []).slice(0, 3);
                root.city = j.city ?? "";
            } catch (e) {
                console.warn("LockWeather: bad weather.json", e);
            }
        }
    }

    Timer {
        interval: 300000
        running: root.visible
        repeat: true
        onTriggered: cache.reload()
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spaceSm

        SectionHeader {
            text: root.city || "Weather"
        }

        Row {
            width: parent.width
            spacing: Theme.spaceMd

            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.cc ? Icons.getWeatherIcon(String(root.cc.weatherCode)) : "cloud_off"
                size: 40
                color: Theme.spark
                animate: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                GlyphText {
                    role: "title"
                    text: root.cc ? root.temp(root.cc.tempC, root.cc.tempF) : "--°"
                }

                GlyphText {
                    role: "small"
                    dim: true
                    text: root.cc ? `${root.cc.weatherDesc} · ${root.cc.humidity}%` : "No data"
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spaceSm
            visible: root.forecast.length > 0

            Repeater {
                model: root.forecast

                Row {
                    required property var modelData

                    spacing: Theme.spaceXs

                    GlyphText {
                        role: "label"
                        dim: true
                        text: modelData.day ?? ""
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    GlyphIcon {
                        icon: modelData.icon ?? "cloud"
                        size: 14
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    GlyphText {
                        role: "small"
                        text: root.temp(modelData.maxTempC, modelData.maxTempF)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
