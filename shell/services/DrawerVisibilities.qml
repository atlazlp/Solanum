import QtQuick

// One per screen. Every drawer name from docs/dev/design-shell.md is a bool here.
// Panels.qml reads these; Visibilities.qml owns the per-screen registry.
QtObject {
    property bool launcher: false
    property bool windowPicker: false
    property bool dashboard: false
    property bool sidebar: false
    property bool shipLog: false
    property bool session: false
    property bool utilities: false
    property bool quantumMoon: false
    property bool osd: false
    property bool services: false
    property bool kvm: false
    property bool audio: false
    property bool updates: false
    property bool settings: false

    // Not a drawer: set while a panel wants keyboard focus (drawers window flips keyboardFocus to OnDemand).
    property bool wantsKeyboard: launcher || windowPicker || session || settings || shipLog || kvm || audio || services || updates

    readonly property list<string> names: ["launcher", "windowPicker", "dashboard", "sidebar", "shipLog", "session", "utilities", "quantumMoon", "osd", "services", "kvm", "audio", "updates", "settings"]

    function anyOpen(): bool {
        return names.some(n => this[n]);
    }

    function closeAll(): void {
        for (const n of names)
            this[n] = false;
    }
}
