import QtQuick

// One slot PNG, cover-cropped to the screen. `path` is a plain filesystem path.
Item {
    id: root

    property string path: ""

    Image {
        anchors.fill: parent
        source: root.path.length ? "file://" + root.path : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        sourceSize.width: root.width
        sourceSize.height: root.height

        onStatusChanged: {
            if (status === Image.Error)
                console.warn("SlotWallpaper: cannot load", root.path);
        }
    }
}
