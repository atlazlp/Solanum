import QtQuick
import qs.theme

// Wraps children; trigger() plays the write-in: each child fades from 0 and slides 24 px,
// staggered by Motion.glyphStagger (max Motion.glyphStaggerMax children staggered).
Item {
    id: root

    default property alias content: inner.data
    property int translate: Motion.panelTranslate
    property int direction: 1            // 1 = from the right, -1 = from the left
    property bool autoTrigger: true      // play once on completion

    implicitWidth: inner.implicitWidth
    implicitHeight: inner.implicitHeight

    property var _anims: []

    function trigger(): void {
        for (const a of _anims)
            a.destroy();
        _anims = [];
        const kids = inner.children.filter(c => c.visible !== false);
        for (let i = 0; i < kids.length; i++) {
            const k = kids[i];
            const delay = Math.min(i, Motion.glyphStaggerMax) * Motion.glyphStagger;
            const anim = animComp.createObject(root, { target: k, delay: delay });
            _anims.push(anim);
            anim.start();
        }
    }

    Component.onCompleted: {
        if (autoTrigger)
            Qt.callLater(trigger);
    }

    Item {
        id: inner
        anchors.fill: parent
        implicitWidth: {
            let w = 0;
            for (const c of children)
                if (c.visible !== false)
                    w = Math.max(w, c.implicitWidth);
            return w;
        }
        implicitHeight: {
            let h = 0;
            for (const c of children)
                if (c.visible !== false)
                    h = Math.max(h, c.implicitHeight);
            return h;
        }
    }

    Component {
        id: animComp

        SequentialAnimation {
            id: seq

            required property Item target
            property int delay: 0
            property Translate tr: Translate { x: root.translate * root.direction }

            Component.onCompleted: {
                target.opacity = 0;
                target.transform = [tr];
            }

            PauseAnimation { duration: seq.delay }

            ParallelAnimation {
                NumberAnimation {
                    target: seq.target
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Motion.panelOpen
                    easing.type: Motion.enter
                }
                NumberAnimation {
                    target: seq.tr
                    property: "x"
                    from: root.translate * root.direction
                    to: 0
                    duration: Motion.panelOpen
                    easing.type: Motion.slide
                }
            }
        }
    }
}
