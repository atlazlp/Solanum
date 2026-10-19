.pragma library

function clamp01(x) {
    return Math.max(0, Math.min(1, x));
}

function channel(x) {
    const n = Math.max(0, Math.min(255, Math.round(clamp01(x) * 255)));
    const s = n.toString(16);
    return s.length === 1 ? "0" + s : s;
}

function plainHex(r, g, b) {
    return (channel(r) + channel(g) + channel(b)).toUpperCase();
}

function toHsv(r, g, b) {
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const d = max - min;
    let h = 0;
    if (d !== 0) {
        if (max === r)
            h = ((g - b) / d) % 6;
        else if (max === g)
            h = (b - r) / d + 2;
        else
            h = (r - g) / d + 4;
        h *= 60;
        if (h < 0)
            h += 360;
    }
    return { h: h, s: max === 0 ? 0 : d / max, v: max };
}

function fromHsv(h, s, v) {
    const c = v * s;
    const x = c * (1 - Math.abs((h / 60) % 2 - 1));
    const m = v - c;
    let r = 0;
    let g = 0;
    let b = 0;
    if (h < 60) {
        r = c;
        g = x;
    } else if (h < 120) {
        r = x;
        g = c;
    } else if (h < 180) {
        g = c;
        b = x;
    } else if (h < 240) {
        g = x;
        b = c;
    } else if (h < 300) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }
    return { r: r + m, g: g + m, b: b + m };
}
