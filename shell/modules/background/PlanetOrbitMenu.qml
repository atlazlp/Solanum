pragma ComponentBehavior: Bound

import QtQuick
import qs.theme
import qs.components
import qs.services

// Right-click a planet. Satellite, orbit, and video each offer the other two.
Item {
    id: root

    anchors.fill: parent

    property bool menuOpen: false
    property string bodyId: ""
    property alias hitTwins: hitTwins
    property alias hitTimber: hitTimber
    property alias hitBrittle: hitBrittle
    property alias hitGiants: hitGiants
    property alias hitBramble: hitBramble
    property alias dismiss: dismiss
    property alias menuBox: menuBox

    readonly property bool inOrbit: String(SolarTracker.data?.orbit_body ?? "").length > 0
    readonly property string videoBody: SolarTracker.planetVideoBody
    readonly property bool videoMode: videoBody.length > 0 && QuantumMoonWallpaper.centerUsesVideo()
    readonly property string titleId: videoMode ? videoBody : (inOrbit ? String(SolarTracker.data?.orbit_body ?? "") : bodyId)
    property alias videoHit: videoHit
    property real menuPx: 0
    property real menuPy: 0
    readonly property var names: ({
        hourglass_twins: "Hourglass Twins",
        timber_hearth: "Timber Hearth",
        brittle_hollow: "Brittle Hollow",
        giants_deep: "Giant's Deep",
        dark_bramble: "Dark Bramble"
    })
    readonly property var slugs: ({
        hourglass_twins: "hourglass-twins",
        timber_hearth: "timber-hearth",
        brittle_hollow: "brittle-hollow",
        giants_deep: "giants-deep",
        dark_bramble: "dark-bramble"
    })
    readonly property string currentHostBody: SolarTracker.hostToBody[QuantumMoon.slug] || SolarTracker.hostToBody[SolarTracker.qmHost] || ""
    readonly property bool canTravel: titleId.length > 0 && titleId !== currentHostBody

    onMenuOpenChanged: SolarTracker.setMenuHold(menuOpen)
    Component.onDestruction: SolarTracker.setMenuHold(false)

    function openMenu(id: string, px: real, py: real): void {
        bodyId = id;
        menuPx = px;
        menuPy = py;
        menuOpen = true;
        Qt.callLater(root.placeMenu);
    }

    function placeMenu(): void {
        const boxW = menuBox.implicitWidth;
        const boxH = menuBox.implicitHeight;
        menuBox.x = Math.max(Theme.spaceSm, Math.min(width - boxW - Theme.spaceSm, menuPx));
        menuBox.y = Math.max(Theme.spaceSm, Math.min(height - boxH - Theme.spaceSm, menuPy));
    }

    Connections {
        target: SolarTracker
        function onSupernovaActiveChanged(): void {
            if (SolarTracker.supernovaActive)
                root.menuOpen = false;
        }
    }

    component PlanetHit: MouseArea {
        id: hit

        property string planetId: ""
        signal pick(real px, real py)

        readonly property var body: SolarTracker.data?.bodies?.[hit.planetId] ?? null
        readonly property bool onScreen: !!(hit.body && hit.body.visible && !SolarTracker.supernovaActive && !root.videoMode)
        readonly property real rad: Math.max(18, Number(hit.body?.r_px) || 0) + 16

        visible: hit.onScreen
        z: 2
        x: (Number(hit.body?.x) || 0) - hit.rad
        y: (Number(hit.body?.y) || 0) - hit.rad
        width: hit.rad * 2
        height: hit.rad * 2
        acceptedButtons: Qt.RightButton
        preventStealing: true

        onPressed: (mouse) => {
            if (mouse.button !== Qt.RightButton)
                return;
            const dx = mouse.x - hit.rad;
            const dy = mouse.y - hit.rad;
            if (dx * dx + dy * dy > hit.rad * hit.rad)
                return;
            hit.pick(hit.x + mouse.x, hit.y + mouse.y);
        }
    }

    PlanetHit {
        id: hitTwins
        planetId: "hourglass_twins"
        onPick: (px, py) => root.openMenu(hitTwins.planetId, px, py)
    }
    PlanetHit {
        id: hitTimber
        planetId: "timber_hearth"
        onPick: (px, py) => root.openMenu(hitTimber.planetId, px, py)
    }
    PlanetHit {
        id: hitBrittle
        planetId: "brittle_hollow"
        onPick: (px, py) => root.openMenu(hitBrittle.planetId, px, py)
    }
    PlanetHit {
        id: hitGiants
        planetId: "giants_deep"
        onPick: (px, py) => root.openMenu(hitGiants.planetId, px, py)
    }
    PlanetHit {
        id: hitBramble
        planetId: "dark_bramble"
        onPick: (px, py) => root.openMenu(hitBramble.planetId, px, py)
    }

    MouseArea {
        id: videoHit
        anchors.fill: parent
        visible: root.videoMode
        z: 2
        acceptedButtons: Qt.RightButton
        onPressed: (mouse) => {
            if (mouse.button !== Qt.RightButton)
                return;
            root.openMenu(root.videoBody, mouse.x, mouse.y);
        }
    }

    MouseArea {
        id: dismiss
        anchors.fill: parent
        visible: root.menuOpen
        z: 1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: root.menuOpen = false
    }

    NomaiFrame {
        id: menuBox
        visible: root.menuOpen
        z: 3
        padding: Theme.spaceSm
        chamfer: Theme.chamferSm
        fill: Theme.alpha(Theme.ink1, 0.94)
        glow: true
        lineColor: Theme.line

        Column {
            id: menuCol
            spacing: Theme.spaceXs

            Item {
                id: menuHead
                implicitWidth: menuTitle.implicitWidth
                implicitHeight: menuTitle.implicitHeight + 8
                width: Math.max(implicitWidth, menuCol.implicitWidth)
                height: implicitHeight

                GlyphText {
                    id: menuTitle
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.names[root.titleId] || ""
                    role: "title"
                    color: Theme.secondary
                    font.letterSpacing: 1.6
                    font.capitalization: Font.AllUppercase
                }

                Rectangle {
                    anchors.top: menuTitle.bottom
                    anchors.topMargin: 6
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(menuTitle.implicitWidth, parent.width)
                    height: 1
                    color: Theme.alpha(Theme.secondary, 0.75)
                }
            }

            MenuChoice {
                visible: root.canTravel
                label: "TRAVEL"
                onChoose: {
                    const slug = root.slugs[root.titleId] || "";
                    if (slug.length)
                        QuantumMoon.applyPlanetSlug(slug);
                    root.menuOpen = false;
                }
            }

            MenuChoice {
                label: root.videoMode || root.inOrbit ? "SATELLITE VIEW" : "ORBIT"
                onChoose: {
                    if (root.videoMode)
                        SolarTracker.restoreScene("overview");
                    else if (root.inOrbit)
                        SolarTracker.returnOverview();
                    else
                        SolarTracker.orbitBody(root.bodyId);
                    root.menuOpen = false;
                }
            }

            MenuChoice {
                label: root.videoMode ? "ORBIT" : "VIDEO"
                onChoose: {
                    if (root.videoMode)
                        SolarTracker.restoreScene("orbit");
                    else
                        SolarTracker.playPlanetVideo(root.titleId);
                    root.menuOpen = false;
                }
            }
        }
    }

    component MenuChoice: MouseArea {
        id: row

        property string label: ""
        signal choose()

        implicitWidth: row.visible ? Math.max(rowLabel.implicitWidth + Theme.spaceLg * 2, 188) : 0
        width: Math.max(implicitWidth, menuCol.implicitWidth)
        height: row.visible ? rowLabel.implicitHeight + Theme.spaceSm * 2 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.choose()

        Rectangle {
            anchors.fill: parent
            color: row.containsMouse ? Theme.alpha(Theme.line, 0.18) : "transparent"
        }

        GlyphText {
            id: rowLabel
            anchors.centerIn: parent
            text: row.label
            role: "small"
            color: Theme.spark
            font.letterSpacing: Theme.letterSpacingHeader
            font.bold: true
        }
    }
}
