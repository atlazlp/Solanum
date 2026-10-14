import QtQuick

// argv list shown as one space-separated command line (mono); stored back as a string list.
TextRow {
    mono: true
    fieldWidth: 360
    placeholder: "command arg..."
    toText: v => Array.isArray(v) ? v.join(" ") : (v === undefined || v === null ? "" : String(v))
    fromText: t => t.trim() === "" ? [] : t.trim().split(/\s+/)
}
