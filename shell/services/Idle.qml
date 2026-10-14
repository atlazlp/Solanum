pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Placeholder for modules/IdleMonitors.qml: exposes whether idle actions are currently inhibited.
Singleton {
    readonly property bool inhibited: IdleInhibitor.enabled || Recorder.running || GameMode.enabled
}
