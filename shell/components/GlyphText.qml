import QtQuick
import qs.theme

// Text with a typographic role.
// title/display → Avant Garde · label/large → Serif Gothic · body/small/mono → Space Mono
Text {
    id: root

    property string role: "body"
    property bool dim: false
    property bool animate: false
    property bool filterHidden: false

    states: State {
        name: "filtered"
        when: root.filterHidden
        PropertyChanges {
            root.visible: false
            root.height: 0
        }
    }

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

    readonly property string roleFamily: {
        switch (role) {
        case "display":
        case "title":
            return Theme.fontDisplay;
        case "label":
        case "large":
            return Theme.fontSubtitle;
        default:
            return Theme.fontBody;
        }
    }

    color: dim ? Theme.textDim : Theme.text
    font.pointSize: roleSize
    font.family: roleFamily
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
