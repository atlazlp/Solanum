pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

SettingsPane {
    id: pane

    readonly property list<var> kinds: [
        { value: "lock", label: "Lock" },
        { value: "suspend", label: "Suspend" },
        { value: "dpms", label: "DPMS off" },
        { value: "custom", label: "Custom command" }
    ]

    readonly property var timeouts: {
        void SettingsStore.generation;
        const t = toArray(SettingsStore.get("general.idle.timeouts", []));
        return t ?? [];
    }

    // Values that crossed a QVariant boundary arrive as sequence wrappers, not JS arrays.
    function toArray(v: var): var {
        if (Array.isArray(v))
            return v;
        if (v !== null && typeof v === "object" && typeof v.length === "number")
            return Array.from(v);
        return null;
    }

    function kindOf(action: var): string {
        if (action === "lock")
            return "lock";
        if (action === "dpms off")
            return "dpms";
        const a = toArray(action);
        if (a && a.join(" ") === "systemctl suspend")
            return "suspend";
        return "custom";
    }

    function argvText(action: var): string {
        const a = toArray(action);
        return a ? a.join(" ") : (typeof action === "string" ? action : "");
    }

    function actionFor(kind: string, custom: string): var {
        switch (kind) {
        case "lock": return "lock";
        case "suspend": return ["systemctl", "suspend"];
        case "dpms": return "dpms off";
        default: return custom.trim() === "" ? [] : custom.trim().split(/\s+/);
        }
    }

    function write(next: var): void {
        SettingsStore.set("general.idle.timeouts", next);
    }

    function patch(i: int, p: var): void {
        const next = timeouts.map(t => Object.assign({}, t));
        next[i] = Object.assign(next[i], p);
        write(next);
    }

    function remove(i: int): void {
        const next = timeouts.slice();
        next.splice(i, 1);
        write(next);
    }

    function add(): void {
        const last = timeouts.length ? Number(timeouts[timeouts.length - 1].timeout ?? 0) : 0;
        write(timeouts.concat([{ timeout: last + 300, idleAction: "lock" }]));
    }

    SettingRow {
        key: "general.idle.timeouts"
        label: "Idle timeouts"
        description: "After N seconds without input run an action. Inhibited while audio plays if enabled below."
        stacked: true

        Column {
            width: parent.width
            spacing: Theme.spaceXs

            Repeater {
                model: pane.timeouts

                Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property string kind: pane.kindOf(modelData.idleAction)

                    width: parent.width
                    height: 44

                    NomaiFrame {
                        anchors.fill: parent
                        padding: 0
                        chamfer: Theme.chamferSm
                        fill: Theme.ink0
                        lineOpacity: 0.35
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceSm
                        anchors.right: removeBtn.left
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceSm

                        NomaiNumber {
                            value: Number(entry.modelData.timeout ?? 0)
                            from: 10
                            to: 86400
                            step: 30
                            suffix: "s"
                            anchors.verticalCenter: parent.verticalCenter
                            onEdited: v => pane.patch(entry.index, { timeout: v })
                        }

                        NomaiCombo {
                            implicitWidth: 170
                            model: pane.kinds
                            currentValue: entry.kind
                            anchors.verticalCenter: parent.verticalCenter
                            onActivated: k => pane.patch(entry.index, { idleAction: pane.actionFor(k, pane.argvText(entry.modelData.idleAction)) })
                        }

                        NomaiTextField {
                            id: customField
                            visible: entry.kind === "custom"
                            implicitWidth: 300
                            placeholder: "command arg..."
                            input.font.family: Theme.fontMono
                            text: pane.argvText(entry.modelData.idleAction)
                            anchors.verticalCenter: parent.verticalCenter
                            onAccepted: input.focus = false
                            onEscaped: input.focus = false
                            input.onEditingFinished: {
                                if (customField.text !== pane.argvText(entry.modelData.idleAction))
                                    pane.patch(entry.index, { idleAction: pane.actionFor("custom", customField.text) });
                            }
                        }
                    }

                    HexButton {
                        id: removeBtn
                        icon: "delete"
                        flat: true
                        danger: true
                        padding: Theme.spaceXs
                        tooltip: "Remove"
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spaceXs
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: pane.remove(entry.index)
                    }
                }
            }

            HexButton {
                text: "Add timeout"
                icon: "add"
                onClicked: pane.add()
            }
        }
    }

    SwitchRow {
        key: "general.idle.inhibitWhenAudio"
        label: "Inhibit while audio plays"
    }

    SwitchRow {
        key: "general.idle.lockBeforeSleep"
        label: "Lock before sleep"
    }

    NumberRow {
        key: "general.idle.lockedSleepAfter"
        label: "Sleep after lock"
        description: "Seconds after locking before the session suspends (0 = never)"
        from: 0
        to: 7200
        step: 30
        suffix: "s"
        fallback: 300
    }

    NumberRow {
        key: "general.idle.lockTimeout"
        label: "Lock timeout"
        description: "Used only when the timeout list above is empty"
        from: 60
        to: 86400
        step: 60
        suffix: "s"
        visible: pane.timeouts.length === 0 && SettingsStore.has("general.idle.lockTimeout")
    }

    NumberRow {
        key: "general.idle.suspendTimeout"
        label: "Suspend timeout"
        description: "Used only when the timeout list above is empty"
        from: 60
        to: 86400
        step: 60
        suffix: "s"
        visible: pane.timeouts.length === 0 && SettingsStore.has("general.idle.suspendTimeout")
    }

    SectionHeader {
        text: "Lock screen"
        topPadding: Theme.spaceLg
    }

    SwitchRow {
        key: "lock.enableFprint"
        label: "Fingerprint"
        description: "Try fprintd alongside the password"
    }

    NumberRow {
        key: "lock.maxFprintTries"
        label: "Fingerprint tries"
        from: 1
        to: 10
        fallback: 3
    }

    SwitchRow {
        key: "lock.hideNotifs"
        label: "Hide notifications"
    }

    SliderRow {
        key: "lock.blur"
        label: "Blur"
        from: 0
        to: 128
        step: 4
        suffix: "px"
        fallback: 48
    }

    SliderRow {
        key: "lock.scrim"
        label: "Scrim"
        description: "Darkness of the veil over the wallpaper"
        from: 0
        to: 100
        step: 5
        displayScale: 100
        suffix: "%"
        decimals: 0
        fallback: 0.45
    }
}
