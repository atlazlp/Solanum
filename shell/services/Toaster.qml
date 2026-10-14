pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Toast queue. toast(title, message, icon, type, timeout). type: info | success | warn | error.
// Rendered by modules/drawers/Toasts.qml on the main screen.
Singleton {
    id: root

    property list<var> toasts: []
    property int nextId: 1
    property int maxVisible: 4

    signal added(var toast)

    function toast(title: string, message: string, icon: string, type: string, timeout: int): void {
        const t = {
            id: nextId++,
            title: title ?? "",
            message: message ?? "",
            icon: icon && icon.length ? icon : "info",
            type: ["info", "success", "warn", "error"].includes(type) ? type : "info",
            timeout: timeout && timeout > 0 ? timeout : (type === "error" ? 8000 : 5000),
            time: new Date()
        };
        const next = toasts.concat([t]);
        toasts = next.length > maxVisible ? next.slice(next.length - maxVisible) : next;
        added(t);
    }

    function dismiss(id: int): void {
        toasts = toasts.filter(t => t.id !== id);
    }

    function clear(): void {
        toasts = [];
    }

    IpcHandler {
        target: "toast"

        function info(title: string, message: string, icon: string): void {
            root.toast(title, message, icon, "info", 0);
        }

        function success(title: string, message: string, icon: string): void {
            root.toast(title, message, icon, "success", 0);
        }

        function warn(title: string, message: string, icon: string): void {
            root.toast(title, message, icon, "warn", 0);
        }

        function error(title: string, message: string, icon: string): void {
            root.toast(title, message, icon, "error", 0);
        }
    }
}
