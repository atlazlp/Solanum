import QtQuick
import qs.theme

// Text with a typographic role. role: label | small | body | large | title | display | mono
Text {
    id: root

    property string role: "body"
    property bool dim: false
    property bool animate: false

    readonly property real roleSize: {
        switch (role) {
        case "label": return Theme.sizeLabel;
        case "small": return Theme.sizeSmall;
        case "large": return Theme.sizeLarge;
        case "title": return Theme.sizeTitle;
        case "display": return Theme.sizeDisplay;
        case "mono": return Theme.sizeBody;
        default: return Theme.sizeBody;
        }
    }

    color: dim ? Theme.textDim : Theme.text
    font.pointSize: roleSize
    font.family: role === "display" || role === "title" ? Theme.fontDisplay : (role === "mono" ? Theme.fontMono : Theme.fontBody)
    font.weight: role === "title" || role === "display" ? Font.DemiBold : Font.Normal
    font.letterSpacing: role === "label" ? Theme.letterSpacingHeader : (role === "display" ? 1 : 0)
    font.capitalization: role === "label" ? Font.AllUppercase : Font.MixedCase
    renderType: Text.NativeRendering
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        enabled: root.animate
        ColorAnimation {
            duration: Motion.normal
            easing.type: Motion.fade
        }
    }
}
