pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// hyprsunset control: `hyprctl hyprsunset temperature <K>` / `identity`.
Singleton {
    id: root

    property alias enabled: props.enabled
    property alias temperature: props.temperature

    function apply(): void {
        if (enabled)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(temperature)]);
        else
            Quickshell.execDetached(["hyprctl", "hyprsunset", "identity"]);
    }

    function set(kelvin: int): void {
        props.temperature = Math.max(1000, Math.min(20000, kelvin));
        props.enabled = true;
        apply();
    }

    function toggle(): void {
        props.enabled = !props.enabled;
        apply();
    }

    PersistentProperties {
        id: props
        property bool enabled: false
        property int temperature: Config.nightlight.temperature ?? 4000
        reloadableId: "nightLight"
    }

    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            root.toggle();
        }

        function set(kelvin: int): void {
            root.set(kelvin);
        }

        function isEnabled(): bool {
            return props.enabled;
        }

        function enable(): void {
            props.enabled = true;
            root.apply();
        }

        function disable(): void {
            props.enabled = false;
            root.apply();
        }
    }
}
