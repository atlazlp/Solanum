pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.config
import qs.services

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    readonly property MprisPlayer active: props.manualActive ?? list.find(p => p.isPlaying) ?? list[0] ?? null
    property alias manualActive: props.manualActive

    function getArtUrl(player: MprisPlayer): string {
        if (!player)
            return "";
        if (player.trackArtUrl)
            return player.trackArtUrl;
        const url = player.metadata["xesam:url"] ?? "";
        if (url.startsWith("https://www.youtube.com/watch")) {
            const id = url.match(/[?&]v=([\w-]{11})/)?.[1];
            return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : "";
        }
        return "";
    }

    function playPause(): void {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function next(): void {
        if (active?.canGoNext)
            active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    function stop(): void {
        active?.stop();
    }

    Connections {
        target: root.active

        function onPostTrackChanged(): void {
            if (!Config.utilities.toasts.nowPlaying)
                return;
            if (root.active.trackArtist !== "" && root.active.trackTitle !== "")
                Toaster.toast("Now Playing", `${root.active.trackArtist} - ${root.active.trackTitle}`, "music_note", "info", 0);
        }
    }

    PersistentProperties {
        id: props
        property MprisPlayer manualActive
        reloadableId: "players"
    }

    IpcHandler {
        target: "mpris"

        function getActive(prop: string): string {
            const a = root.active;
            return a ? String(a[prop] ?? "Invalid property") : "No active player";
        }

        function list(): string {
            return root.list.map(p => p.identity).join("\n");
        }

        function play(): void {
            if (root.active?.canPlay)
                root.active.play();
        }

        function pause(): void {
            if (root.active?.canPause)
                root.active.pause();
        }

        function playPause(): void {
            root.playPause();
        }

        function previous(): void {
            root.previous();
        }

        function next(): void {
            root.next();
        }

        function stop(): void {
            root.stop();
        }
    }
}
