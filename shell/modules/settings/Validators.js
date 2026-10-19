.pragma library

function url(t) {
    const s = String(t ?? "").trim();
    if (s === "")
        return "";
    if (!/^https?:\/\/\S+$/i.test(s))
        return "Enter an http or https URL";
    return "";
}

function weather(t) {
    const s = String(t ?? "").trim();
    if (s === "")
        return "";
    if (s.indexOf(",") === -1)
        return s.length > 80 ? "Location is too long" : "";
    const parts = s.split(",");
    if (parts.length !== 2)
        return "Use lat,lon or a place name";
    const lat = Number(parts[0].trim());
    const lon = Number(parts[1].trim());
    if (isNaN(lat) || isNaN(lon) || !isFinite(lat) || !isFinite(lon))
        return "Use lat,lon or a place name";
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180)
        return "Latitude or longitude is out of range";
    return "";
}

function regex(t) {
    const s = String(t ?? "").trim();
    if (s === "")
        return "";
    try {
        RegExp(s);
        return "";
    } catch (e) {
        return "Not a valid regular expression";
    }
}
