pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Durations (ms) and easing curves. No springs, no bounces.
Singleton {
    id: root

    readonly property real scale: Config.appearance.motionScale ?? 1

    readonly property int fast: Math.round(110 * scale)
    readonly property int normal: Math.round(180 * scale)
    readonly property int slow: Math.round(260 * scale)
    readonly property int reveal: Math.round(420 * scale)
    readonly property int press: Math.round(90 * scale)
    readonly property int panelOpen: Math.round(200 * scale)
    readonly property int panelClose: Math.round(140 * scale)
    readonly property int glyphStagger: Math.round(14 * scale)
    readonly property int glyphStaggerMax: 12
    readonly property int panelTranslate: 24

    readonly property int enter: Easing.OutCubic
    readonly property int exit: Easing.InCubic
    readonly property int slide: Easing.OutQuart
    readonly property int spin: Easing.InOutQuint
    readonly property int fade: Easing.InOutQuad
}
