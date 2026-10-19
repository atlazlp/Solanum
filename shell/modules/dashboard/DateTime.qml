import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.services

// Big clock + date for the Dash tab.
Column {
    id: root

    readonly property bool twelveHour: Config.get("dashboard.weather.useTwelveHourClock", false)

    spacing: Theme.spaceXs

    Row {
        spacing: Theme.spaceSm

        GlyphText {
            role: "display"
            text: Time.format(root.twelveHour ? "h:mm" : "HH:mm")
            font.pointSize: 42
            color: Theme.text
        }

        Column {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            spacing: 0

            GlyphText {
                role: "title"
                text: root.twelveHour ? Time.format("AP") : ""
                visible: root.twelveHour
                color: Theme.spark
            }

            GlyphText {
                role: "mono"
                text: Time.format("ss")
                color: Theme.spark
                opacity: 0.8
            }
        }
    }

    Row {
        spacing: Theme.spaceSm

        NomaiDivider {
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.spark
        }

        GlyphText {
            role: "label"
            text: Time.format("dddd")
            color: Theme.spark
            anchors.verticalCenter: parent.verticalCenter
        }

        GlyphText {
            role: "body"
            text: Time.format("d MMMM yyyy")
            dim: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
