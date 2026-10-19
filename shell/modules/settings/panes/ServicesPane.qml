import QtQuick
import qs.config
import qs.theme
import qs.components
import qs.modules.settings
import "../Validators.js" as Validators

SettingsPane {
    id: pane

    JsonStore {
        id: services
        path: `${Paths.config}/services.json`
    }

    GlyphText {
        text: services.loaded ? Paths.config.replace(Paths.home, "~") + "/services.json" : "services.json will be created on the first change"
        role: "small"
        dim: true
        bottomPadding: Theme.spaceSm
    }

    SectionHeader {
        text: "LLM"
    }

    TextRow {
        store: services
        key: "llm.controlScript"
        label: "Control script"
        description: "Script handling start / stop / status"
        placeholder: "/path/to/llm-control.sh"
        fieldWidth: 420
        mono: true
    }

    TextRow {
        store: services
        key: "llm.ollamaUrl"
        label: "Ollama URL"
        placeholder: "http://127.0.0.1:11434"
        fieldWidth: 420
        mono: true
        validate: t => Validators.url(t)
    }

    TextRow {
        store: services
        key: "llm.webuiUrl"
        label: "Web UI URL"
        placeholder: "http://127.0.0.1:8080"
        fieldWidth: 420
        mono: true
        validate: t => Validators.url(t)
    }

    TextRow {
        store: services
        key: "llm.composeDir"
        label: "Compose directory"
        placeholder: "/path/to/compose"
        fieldWidth: 420
        mono: true
    }

    SectionHeader {
        text: "KVM"
        topPadding: Theme.spaceLg
    }

    TextRow {
        store: services
        key: "kvm.launchScript"
        label: "Launch script"
        placeholder: "/path/to/lan-mouse-launch.sh"
        fieldWidth: 420
        mono: true
    }

    TextRow {
        store: services
        key: "kvm.clipboardScript"
        label: "Clipboard script"
        placeholder: "/path/to/clipboard-sync.sh"
        fieldWidth: 420
        mono: true
    }

    TextRow {
        store: services
        key: "kvm.logPath"
        label: "Log path"
        placeholder: "~/.local/state/lan-kvm-hyprland/uniclip.log"
        fieldWidth: 420
        mono: true
    }
}
