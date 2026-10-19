import QtQuick
import qs.theme
import qs.components
import qs.modules.settings

// Scrollable column of rows / section headers. Children go in the column; it is as wide as the pane
// minus the scrollbar gutter. `filter` hides rows whose label, description, and nested text do not match.
Flickable {
    id: root

    default property alias content: column.data
    property alias spacing: column.spacing
    property string filter: ""
    property int matches: 0
    property bool scrollHot: false

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + Theme.spaceLg
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    readonly property int childCount: column.children.length
    onFilterChanged: applyFilter()
    onChildCountChanged: applyFilter()
    onMovementStarted: scrollHot = true
    onMovementEnded: scrollCool.restart()
    onContentYChanged: {
        scrollHot = true;
        scrollCool.restart();
    }

    function childText(c, depth: int): string {
        if (!c || depth > 8)
            return "";
        let s = "";
        if (c instanceof GlyphText || c instanceof SectionHeader)
            s += " " + c.text;
        else if (c instanceof SettingRow)
            s += " " + c.label + " " + c.description + " " + c.filterText;
        const kids = c.children;
        if (kids) {
            for (let i = 0; i < kids.length; i++)
                s += childText(kids[i], depth + 1);
        }
        return s;
    }

    function naturallyHidden(c): bool {
        return c instanceof SettingRow && c.key !== "" && !c.store.has(c.key);
    }

    function visuals(): var {
        const out = [];
        const kids = column.children;
        for (let i = 0; i < kids.length; i++) {
            const c = kids[i];
            if (!c || c instanceof Repeater)
                continue;
            out.push(c);
        }
        return out;
    }

    function setHidden(item, hidden: bool): void {
        if (item)
            item.filterHidden = hidden;
    }

    function applyFilter(): void {
        const f = filter.trim().toLowerCase();
        const rows = visuals();
        const hit = [];
        for (let i = 0; i < rows.length; i++) {
            if (naturallyHidden(rows[i]))
                hit.push(false);
            else if (f === "")
                hit.push(true);
            else
                hit.push(childText(rows[i], 0).toLowerCase().indexOf(f) >= 0);
        }

        let shown = 0;
        let i = 0;
        while (i < rows.length) {
            if (rows[i] instanceof SectionHeader) {
                let j = i + 1;
                let headerMatch = hit[i];
                let anyRow = false;
                while (j < rows.length && !(rows[j] instanceof SectionHeader)) {
                    if (hit[j] && !(rows[j] instanceof GlyphText))
                        anyRow = true;
                    j++;
                }
                for (let k = i; k < j; k++) {
                    const glyph = rows[k] instanceof GlyphText;
                    const header = rows[k] instanceof SectionHeader;
                    const show = f === "" || (header ? (headerMatch || anyRow) : (headerMatch || hit[k] || (glyph && anyRow)));
                    setHidden(rows[k], !show);
                    if (show && hit[k] && !naturallyHidden(rows[k]))
                        shown++;
                }
                i = j;
            } else {
                const show = f === "" || hit[i];
                setHidden(rows[i], !show);
                if (show && hit[i] && !naturallyHidden(rows[i]))
                    shown++;
                i++;
            }
        }
        matches = f === "" ? Math.max(shown, rows.length > 0 ? 1 : 0) : shown;
    }

    Component.onCompleted: applyFilter()

    Timer {
        id: scrollCool
        interval: 700
        onTriggered: root.scrollHot = false
    }

    Column {
        id: column
        width: root.width - Theme.spaceLg
        spacing: 0
    }

    Rectangle {
        visible: root.contentHeight > root.height
        opacity: root.scrollHot || scrollHover.hovered ? 1 : 0
        anchors.right: parent.right
        anchors.rightMargin: 2
        width: 2
        y: root.height * root.visibleArea.yPosition
        height: Math.max(16, root.height * root.visibleArea.heightRatio)
        color: Theme.alpha(Theme.line, 0.6)

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.fast
                easing.type: Motion.fade
            }
        }

        HoverHandler {
            id: scrollHover
        }
    }
}
