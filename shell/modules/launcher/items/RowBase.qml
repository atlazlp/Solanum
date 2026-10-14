import QtQuick
import qs.theme

// Shared launcher/window row: fixed height from the owning list, hover state, left/right tap,
// staggered write-in (opacity + 24 px slide) when the list is revealing.
Item {
    id: root

    required property var modelData
    required property int index
    property var list: ListView.view
    default property alias content: inner.data
    readonly property bool rowHovered: hover.hovered
    property bool selectable: true
    readonly property bool current: list ? list.currentIndex === index : false

    signal activated()
    signal rightClicked()

    width: ListView.view?.width ?? 0
    implicitHeight: list?.rowHeight ?? 44
    height: implicitHeight

    transform: Translate { id: slide }

    function reveal(): void {
        revealAnim.stop();
        revealAnim.delay = Math.min(index, Motion.glyphStaggerMax) * Motion.glyphStagger;
        revealAnim.start();
    }

    Component.onCompleted: {
        if (list?.revealing)
            reveal();
    }

    SequentialAnimation {
        id: revealAnim
        property int delay: 0
        PropertyAction { target: root; property: "opacity"; value: 0 }
        PropertyAction { target: slide; property: "x"; value: Motion.panelTranslate }
        PauseAnimation { duration: revealAnim.delay }
        ParallelAnimation {
            NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Motion.panelOpen; easing.type: Motion.enter }
            NumberAnimation { target: slide; property: "x"; from: Motion.panelTranslate; to: 0; duration: Motion.panelOpen; easing.type: Motion.slide }
        }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered && root.selectable && root.list && root.list.hoverSelects)
                root.list.select(root.index, 1);
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (point, button) => {
            if (button === Qt.RightButton)
                root.rightClicked();
            else
                root.activated();
        }
    }

    Item {
        id: inner
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceMd
        anchors.rightMargin: Theme.spaceMd
    }
}
