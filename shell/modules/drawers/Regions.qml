import QtQuick
import Quickshell

// Input mask for the drawers window: the union of every visible panel slot, the popout host,
// the hover strips, the dismiss catcher and the toasts. Everything else is click-through.
Region {
    id: root

    required property Item panels
    required property Item strips
    required property Item toasts
    required property Item popouts
    property Item dismiss: null

    Region { item: root.dismiss && root.dismiss.visible ? root.dismiss : null }
    Region { item: root.panels.dashboard.visible ? root.panels.dashboard : null }
    Region { item: root.panels.quantumMoon.visible ? root.panels.quantumMoon : null }
    Region { item: root.panels.notifications.visible ? root.panels.notifications : null }
    Region { item: root.panels.osd.visible ? root.panels.osd : null }
    Region { item: root.panels.session.visible ? root.panels.session : null }
    Region { item: root.panels.sidebar.visible ? root.panels.sidebar : null }
    Region { item: root.panels.utilities.visible ? root.panels.utilities : null }
    Region { item: root.panels.launcher.visible ? root.panels.launcher : null }
    Region { item: root.panels.windowPicker.visible ? root.panels.windowPicker : null }
    Region { item: root.panels.shipLog.visible ? root.panels.shipLog : null }
    Region { item: root.panels.services.visible ? root.panels.services : null }
    Region { item: root.panels.kvm.visible ? root.panels.kvm : null }
    Region { item: root.panels.audio.visible ? root.panels.audio : null }
    Region { item: root.panels.audioMixer.visible ? root.panels.audioMixer : null }
    Region { item: root.panels.updates.visible ? root.panels.updates : null }
    Region { item: root.panels.settings.visible ? root.panels.settings : null }
    Region { item: root.popouts.hasCurrent ? root.popouts.frame : null }
    Region { item: root.toasts.count > 0 ? root.toasts : null }
    Region { item: root.strips.topCentre.enabled ? root.strips.topCentre : null }
    Region { item: root.strips.topRight.enabled ? root.strips.topRight : null }
    Region { item: root.strips.bottomCentre.enabled ? root.strips.bottomCentre : null }
    Region { item: root.strips.bottomRight.enabled ? root.strips.bottomRight : null }
    Region { item: root.strips.rightEdge.enabled ? root.strips.rightEdge : null }
}
