pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.theme
import qs.components
import qs.services

// GitWatcher configuration: a full-screen overlay window (so it outlives the hover popout) with a
// Nomai modal editing every key of git-watcher.json: credentials, polling, notifications,
// Discord-first (channels grouped by category, loaded via --fetch-discord-channels), colours
// and the watched repositories per project. Opened through GitWatcher.openConfig().
PanelWindow {
    id: win

    screen: Quickshell.screens.find(s => s.name === (Hypr.focusedMonitor?.name ?? "")) ?? Screens.mainScreen ?? null
    color: "transparent"
    WlrLayershell.namespace: "solanum-gitwatcher-config"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    readonly property int formWidth: 480
    readonly property int maxFormHeight: Math.max(320, (win.screen?.height ?? 900) - 160)

    // ---- form state ----
    property var cfg: ({})
    property var projectRepos: []
    property var discordGuilds: []

    property string pat: ""
    property bool patVisible: false
    property string orgUrl: ""
    property string identity: ""
    property int pollInterval: 60
    property int overdueMinutes: 60
    property bool notifyNewPr: true
    property bool notifyComment: true
    property bool notifyMention: true
    property string overdueColor: "#ff9500"
    property string mentionColor: "#e53935"
    property var watchedSet: ({})

    property bool discordEnabled: false
    property string discordToken: ""
    property bool discordTokenVisible: false
    property var discordChannelsSet: ({})
    property bool discordLoading: false

    function syncFormFromCfg(): void {
        pat = cfg.pat ?? "";
        orgUrl = cfg.organizationUrl ?? "";
        identity = cfg.myIdentity ?? "";
        pollInterval = cfg.pollIntervalSeconds ?? 60;
        overdueMinutes = cfg.notifications?.overdueMinutes ?? 60;
        notifyNewPr = cfg.notifications?.newPr ?? true;
        notifyComment = cfg.notifications?.prComment ?? true;
        notifyMention = cfg.notifications?.prMention ?? true;
        overdueColor = cfg.colors?.overdue ?? "#ff9500";
        mentionColor = cfg.colors?.mention ?? "#e53935";
        const set = {};
        for (const k of (cfg.watchedRepos ?? []))
            set[k] = true;
        watchedSet = set;
        discordEnabled = cfg.discordFirst?.enabled ?? false;
        discordToken = cfg.discordFirst?.token ?? "";
        const dset = {};
        for (const c of (cfg.discordFirst?.channels ?? []))
            dset[c] = true;
        discordChannelsSet = dset;
    }

    function setRepoWatched(project: string, repo: string, watch: bool): void {
        const key = `${project}/${repo}`;
        const copy = Object.assign({}, watchedSet);
        delete copy[repo];
        if (watch)
            copy[key] = true;
        else
            delete copy[key];
        watchedSet = copy;
    }

    function setChannelSelected(chId: string, sel: bool): void {
        const copy = Object.assign({}, discordChannelsSet);
        if (sel)
            copy[chId] = true;
        else
            delete copy[chId];
        discordChannelsSet = copy;
    }

    function buildConfig(): string {
        return JSON.stringify({
            enabled: true,
            pat: pat,
            organizationUrl: orgUrl,
            myIdentity: identity,
            pollIntervalSeconds: pollInterval,
            watchedRepos: Object.keys(watchedSet),
            colors: { overdue: overdueColor, mention: mentionColor },
            notifications: {
                newPr: notifyNewPr,
                overdueMinutes: overdueMinutes,
                prComment: notifyComment,
                prMention: notifyMention
            },
            discordFirst: {
                enabled: discordEnabled,
                token: discordToken,
                channels: Object.keys(discordChannelsSet)
            }
        }, null, 2);
    }

    function apply(): void {
        GitWatcher.applyConfig(buildConfig());
        Toaster.toast("GitWatcher", "Configuration saved", "check", "success", 0);
        close();
    }

    function close(): void {
        GitWatcher.closeConfig();
    }

    function loadDiscordChannels(): void {
        if (discordToken.length === 0 || discordLoading)
            return;
        discordLoading = true;
        discordFetchProc.running = true;
    }

    // ---- files ----
    FileView {
        id: cfgFile
        path: GitWatcher.configPath
        printErrors: false
        onLoaded: {
            try {
                win.cfg = JSON.parse(text());
            } catch (e) {
                win.cfg = {};
            }
            win.syncFormFromCfg();
        }
        onLoadFailed: {
            win.cfg = {};
            win.syncFormFromCfg();
        }
    }

    FileView {
        id: reposFile
        path: GitWatcher.reposPath
        printErrors: false
        onLoaded: {
            try {
                win.projectRepos = JSON.parse(text());
            } catch (e) {
                win.projectRepos = [];
            }
        }
    }

    FileView {
        id: discordFile
        path: GitWatcher.discordPath
        printErrors: false
        onLoaded: {
            try {
                win.discordGuilds = JSON.parse(text());
            } catch (e) {
                win.discordGuilds = [];
            }
        }
        onLoadFailed: win.discordGuilds = []
    }

    // Token goes through the environment (never argv) so it does not show up in `ps`.
    Process {
        id: discordFetchProc
        command: ["python3", GitWatcher.daemonPath, "--fetch-discord-channels"]
        environment: ({ GW_DISCORD_TOKEN: win.discordToken })
        onExited: {
            win.discordLoading = false;
            discordFile.reload();
        }
    }

    Modal {
        id: modal
        open: true
        title: "GitWatcher config"
        padding: Theme.spaceLg
        // Pointer handlers do not grab exclusively, so a scrim tap would also fire for taps inside the
        // form; close only through Escape, Cancel or the X button.
        dismissOnScrim: false
        onDismissed: win.close()

        Component.onCompleted: Qt.callLater(() => modal.forceActiveFocus())

        Column {
            width: win.formWidth
            spacing: Theme.spaceMd

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "settings"
                    fill: 1
                    color: Theme.line
                }

                GlyphText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.sizeIcon * 2 - closeBtn.width - parent.spacing * 2
                    text: "Azure DevOps watcher"
                    role: "title"
                }

                HexButton {
                    id: closeBtn
                    anchors.verticalCenter: parent.verticalCenter
                    flat: true
                    icon: "close"
                    padding: Theme.spaceXs
                    onClicked: win.close()
                }
            }

            GlyphText {
                visible: GitWatcher.legacy
                width: parent.width
                role: "small"
                color: Theme.warn
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
                text: "Loaded from the legacy ~/.config/caelestia/git-watcher.json. Apply writes ~/.config/solanum/git-watcher.json and switches the shell to it; stop the old daemon afterwards."
            }

            Flickable {
                id: formScroll
                width: parent.width
                height: Math.min(form.implicitHeight, win.maxFormHeight - 150)
                contentWidth: width
                contentHeight: form.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: form
                    width: formScroll.width
                    spacing: Theme.spaceSm

                    SectionHeader { text: "Credentials" }

                    SecretField {
                        label: "Personal Access Token"
                        hint: "Scopes: Code (Read), Graph (Read)"
                        value: win.pat
                        shown: win.patVisible
                        onEdited: v => win.pat = v
                        onToggleShown: win.patVisible = !win.patVisible
                    }

                    LabeledField { label: "Organization URL"; hint: "https://dev.azure.com/myorg"; value: win.orgUrl; onEdited: v => win.orgUrl = v }
                    LabeledField { label: "My identity (email / UPN)"; hint: "For mention and owned PR detection"; value: win.identity; onEdited: v => win.identity = v }

                    SectionHeader { text: "Polling" }

                    LabeledField {
                        label: "Poll interval (seconds)"
                        hint: "Minimum 10"
                        value: win.pollInterval.toString()
                        onEdited: v => {
                            const n = parseInt(v);
                            if (!isNaN(n))
                                win.pollInterval = Math.max(10, n);
                        }
                    }

                    SectionHeader { text: "Notifications" }

                    SwitchRow { label: "New PR"; checked: win.notifyNewPr; onToggled: c => win.notifyNewPr = c }
                    SwitchRow { label: "Comment on my PR"; checked: win.notifyComment; onToggled: c => win.notifyComment = c }
                    SwitchRow { label: "Mention (@me)"; checked: win.notifyMention; onToggled: c => win.notifyMention = c }

                    LabeledField {
                        label: "Overdue threshold (minutes)"
                        hint: "Stalled and unapproved after this long"
                        value: win.overdueMinutes.toString()
                        onEdited: v => {
                            const n = parseInt(v);
                            if (!isNaN(n))
                                win.overdueMinutes = Math.max(1, n);
                        }
                    }

                    SectionHeader { text: "Discord" }

                    SwitchRow { label: "Discord first"; checked: win.discordEnabled; onToggled: c => win.discordEnabled = c }

                    GlyphText {
                        width: parent.width
                        role: "small"
                        dim: true
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        text: "Hold new-PR alerts until the link is posted to a watched channel."
                    }

                    Column {
                        width: parent.width
                        visible: win.discordEnabled
                        spacing: Theme.spaceSm

                        SecretField {
                            label: "Bot token"
                            hint: "Bot token from the Discord Developer Portal"
                            value: win.discordToken
                            shown: win.discordTokenVisible
                            onEdited: v => win.discordToken = v
                            onToggleShown: win.discordTokenVisible = !win.discordTokenVisible
                        }

                        HexButton {
                            width: parent.width
                            icon: "refresh"
                            text: win.discordLoading ? "Loading channels..." : "Load channels from token"
                            padding: Theme.spaceXs
                            enabled: win.discordToken.length > 0 && !win.discordLoading
                            onClicked: win.loadDiscordChannels()
                        }

                        GlyphText {
                            visible: win.discordGuilds.length === 0
                            width: parent.width
                            role: "small"
                            dim: true
                            wrapMode: Text.WordWrap
                            elide: Text.ElideNone
                            text: "No channels loaded yet: enter a bot token and load. Only the channels selected here release held PR alerts."
                        }

                        Repeater {
                            model: win.discordGuilds

                            GroupSection {
                                required property var modelData
                                width: parent.width
                                name: modelData.guild_name ?? ""
                                items: {
                                    // Channels come ordered by category; insert a header when it changes.
                                    const out = [];
                                    let last = null;
                                    for (const c of (modelData.channels ?? [])) {
                                        const cat = c.category ?? "";
                                        if (cat !== last) {
                                            last = cat;
                                            if (cat.length > 0)
                                                out.push({ header: true, label: cat, id: "", name: "" });
                                        }
                                        out.push({ header: false, label: "", id: c.id, name: `#${c.name}` });
                                    }
                                    return out;
                                }
                                isSelected: id => !!win.discordChannelsSet[id]
                                maxListHeight: 320
                                onToggled: (id, sel) => win.setChannelSelected(id, sel)
                            }
                        }
                    }

                    SectionHeader { text: "Colours" }

                    Row {
                        width: parent.width
                        spacing: Theme.spaceSm

                        LabeledField { width: (parent.width - Theme.spaceSm) / 2; label: "Overdue"; hint: "#ff9500"; value: win.overdueColor; swatch: win.overdueColor; onEdited: v => win.overdueColor = v }
                        LabeledField { width: (parent.width - Theme.spaceSm) / 2; label: "Mention"; hint: "#e53935"; value: win.mentionColor; swatch: win.mentionColor; onEdited: v => win.mentionColor = v }
                    }

                    SectionHeader { text: "Repositories" }

                    GlyphText {
                        visible: win.projectRepos.length === 0
                        width: parent.width
                        role: "small"
                        dim: true
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                        text: "No repos loaded yet: save credentials first and wait for a poll."
                    }

                    Repeater {
                        model: win.projectRepos

                        GroupSection {
                            required property var modelData
                            width: parent.width
                            name: modelData.project ?? ""
                            items: (modelData.repos ?? []).map(r => ({ header: false, label: "", id: r.name, name: r.name }))
                            isSelected: id => !!(win.watchedSet[`${modelData.project}/${id}`] || win.watchedSet[id])
                            maxListHeight: 220
                            onToggled: (id, sel) => win.setRepoWatched(modelData.project, id, sel)
                        }
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                HexButton {
                    width: (parent.width - Theme.spaceSm) / 2
                    icon: "close"
                    text: "Cancel"
                    padding: Theme.spaceXs
                    onClicked: win.close()
                }

                HexButton {
                    width: (parent.width - Theme.spaceSm) / 2
                    icon: "check"
                    text: "Apply"
                    active: true
                    glow: true
                    padding: Theme.spaceXs
                    enabled: win.pat.length > 0 && win.orgUrl.length > 0
                    onClicked: win.apply()
                }
            }
        }
    }

    // ---- helpers ----
    component LabeledField: Column {
        id: lf

        property string label: ""
        property string hint: ""
        property string value: ""
        property string swatch: ""

        signal edited(string val)

        width: parent ? parent.width : 300
        spacing: 2

        GlyphText { text: lf.label; role: "small"; dim: true }

        Row {
            width: parent.width
            spacing: Theme.spaceSm

            NomaiTextField {
                id: tf
                width: parent.width - (sw.visible ? sw.width + parent.spacing : 0)
                placeholder: lf.hint
                text: lf.value
                onTextChanged: {
                    if (text !== lf.value)
                        lf.edited(text);
                }
            }

            Rectangle {
                id: sw
                visible: lf.swatch !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                rotation: 45
                color: lf.swatch
                border.width: 1
                border.color: Theme.lineDim
            }
        }
    }

    component SecretField: Column {
        id: sf

        property string label: ""
        property string hint: ""
        property string value: ""
        property bool shown: false

        signal edited(string val)
        signal toggleShown()

        width: parent ? parent.width : 300
        spacing: 2

        GlyphText { text: sf.label; role: "small"; dim: true }

        Row {
            width: parent.width
            spacing: Theme.spaceSm

            NomaiTextField {
                id: stf
                width: parent.width - eye.width - parent.spacing
                placeholder: sf.hint
                text: sf.value
                input.echoMode: sf.shown ? TextInput.Normal : TextInput.Password
                onTextChanged: {
                    if (text !== sf.value)
                        sf.edited(text);
                }
            }

            HexButton {
                id: eye
                anchors.verticalCenter: parent.verticalCenter
                flat: true
                icon: sf.shown ? "visibility_off" : "visibility"
                padding: Theme.spaceXs
                tooltip: sf.shown ? "Hide" : "Show"
                onClicked: sf.toggleShown()
            }
        }
    }

    component SwitchRow: Item {
        id: sr

        property string label: ""
        property bool checked: false

        signal toggled(bool checked)

        width: parent ? parent.width : 300
        height: 32

        GlyphText {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sr.label
        }

        NomaiSwitch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: sr.checked
            onToggled: c => sr.toggled(c)
        }
    }

    // Expandable group (project -> repos, guild -> channels) with a tri-state master checkbox.
    component GroupSection: Column {
        id: gs

        property string name: ""
        property var items: []               // [{header, label, id, name}]
        property var isSelected: id => false
        property int maxListHeight: 220
        property bool expanded: false

        signal toggled(string id, bool sel)

        readonly property var selectable: items.filter(i => !i.header)
        readonly property int selectedCount: selectable.filter(i => isSelected(i.id)).length
        readonly property int checkState: selectable.length === 0 || selectedCount === 0 ? 0 : (selectedCount === selectable.length ? 2 : 1)

        spacing: 0

        NomaiFrame {
            width: parent.width
            padding: Theme.spaceXs
            chamfer: Theme.chamferSm
            fill: headHover.hovered ? Theme.ink2 : Theme.ink0
            lineOpacity: headHover.hovered ? 1 : 0.4

            HoverHandler { id: headHover }

            Row {
                width: parent.width
                spacing: Theme.spaceSm

                GlyphIcon {
                    id: master
                    anchors.verticalCenter: parent.verticalCenter
                    icon: gs.checkState === 2 ? "check_box" : (gs.checkState === 1 ? "indeterminate_check_box" : "check_box_outline_blank")
                    fill: gs.checkState > 0 ? 1 : 0
                    color: gs.checkState === 2 ? Theme.line : (gs.checkState === 1 ? Theme.spark : Theme.textDim)

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: {
                            const enable = gs.selectedCount === 0;
                            for (const i of gs.selectable)
                                gs.toggled(i.id, enable);
                        }
                    }
                }

                Item {
                    width: parent.width - master.width - parent.spacing
                    height: 28

                    TapHandler {
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: gs.expanded = !gs.expanded
                    }

                    GlyphText {
                        anchors.left: parent.left
                        anchors.right: cnt.left
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        text: gs.name
                        font.weight: Font.DemiBold
                    }

                    GlyphText {
                        id: cnt
                        anchors.right: chevron.left
                        anchors.rightMargin: Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        role: "small"
                        dim: true
                        text: `${gs.selectedCount}/${gs.selectable.length}`
                    }

                    GlyphIcon {
                        id: chevron
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "expand_more"
                        color: Theme.textDim
                        rotation: gs.expanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: Motion.fast; easing.type: Motion.enter }
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: gs.expanded ? Math.min(list.contentHeight + Theme.spaceXs, gs.maxListHeight) : 0
            clip: true

            Behavior on height {
                NumberAnimation { duration: Motion.normal; easing.type: Motion.enter }
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.topMargin: Theme.spaceXs
                model: gs.expanded ? gs.items : []
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: row

                    required property var modelData
                    readonly property bool selected: !modelData.header && gs.isSelected(modelData.id)

                    width: ListView.view.width
                    height: modelData.header ? 24 : 26

                    GlyphText {
                        visible: row.modelData.header
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceMd
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        role: "label"
                        dim: true
                        text: row.modelData.label
                    }

                    Row {
                        visible: !row.modelData.header
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spaceXl
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spaceSm

                        GlyphIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: row.selected ? "check_box" : "check_box_outline_blank"
                            fill: row.selected ? 1 : 0
                            size: Theme.sizeIcon * 0.9
                            color: row.selected ? Theme.line : Theme.textDim
                        }

                        GlyphText {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Theme.sizeIcon - parent.spacing
                            role: "small"
                            text: row.modelData.name
                            color: rowHover.hovered ? Theme.line : Theme.text
                        }
                    }

                    HoverHandler {
                        id: rowHover
                        enabled: !row.modelData.header
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: !row.modelData.header
                        gesturePolicy: TapHandler.ReleaseWithinBounds
                        onTapped: gs.toggled(row.modelData.id, !row.selected)
                    }
                }
            }
        }
    }
}
