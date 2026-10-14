.pragma library

function bytes(n, decimals) {
    if (n === undefined || n === null || isNaN(n))
        return "0 B";
    decimals = decimals === undefined ? 1 : decimals;
    const units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let i = 0;
    let v = Math.abs(n);
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }
    return (n < 0 ? "-" : "") + v.toFixed(i === 0 ? 0 : decimals) + " " + units[i];
}

function rate(bytesPerSec) {
    return bytes(bytesPerSec) + "/s";
}

function pad2(n) {
    return (n < 10 ? "0" : "") + n;
}

// Seconds -> "m:ss" or "h:mm:ss"
function time(seconds) {
    seconds = Math.max(0, Math.floor(seconds || 0));
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return h > 0 ? h + ":" + pad2(m) + ":" + pad2(s) : m + ":" + pad2(s);
}

// Seconds -> "2h 5m", "45s"
function duration(seconds) {
    seconds = Math.max(0, Math.floor(seconds || 0));
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    if (d > 0) return d + "d " + h + "h";
    if (h > 0) return h + "h " + m + "m";
    if (m > 0) return m + "m " + s + "s";
    return s + "s";
}

// Date -> "now", "3 min", "2 h", "yesterday", "12 Mar"
function age(date, now) {
    if (!date) return "";
    now = now || new Date();
    const diff = Math.max(0, (now.getTime() - new Date(date).getTime()) / 1000);
    if (diff < 60) return "now";
    if (diff < 3600) return Math.floor(diff / 60) + " min";
    if (diff < 86400) return Math.floor(diff / 3600) + " h";
    if (diff < 172800) return "yesterday";
    if (diff < 86400 * 30) return Math.floor(diff / 86400) + " d";
    return Qt.formatDate(new Date(date), "d MMM");
}

function percent(v, decimals) {
    return (v * 100).toFixed(decimals || 0) + "%";
}

function capitalize(s) {
    s = String(s || "");
    return s.length ? s[0].toUpperCase() + s.slice(1) : s;
}

function truncate(s, n) {
    s = String(s || "");
    return s.length > n ? s.slice(0, Math.max(0, n - 1)) + "…" : s;
}
