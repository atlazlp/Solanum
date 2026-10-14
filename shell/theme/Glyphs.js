.pragma library

// SVG path builders for QtQuick.Shapes PathSvg. All return a `d` string.

function r(n) {
    return Math.round(n * 100) / 100;
}

// Chamfered rectangle. `corners` is a bitmask: 1 = top-left, 2 = top-right, 4 = bottom-right, 8 = bottom-left.
// Default (5) chamfers top-left and bottom-right only, per the design language.
function chamferRect(w, h, c, corners, inset) {
    corners = corners === undefined ? 5 : corners;
    inset = inset || 0;
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    c = Math.max(0, Math.min(c, (x1 - x0) / 2, (y1 - y0) / 2));
    const tl = corners & 1, tr = corners & 2, br = corners & 4, bl = corners & 8;
    let d = "";
    d += "M " + r(tl ? x0 + c : x0) + " " + r(y0);
    d += " L " + r(tr ? x1 - c : x1) + " " + r(y0);
    if (tr) d += " L " + r(x1) + " " + r(y0 + c);
    d += " L " + r(x1) + " " + r(br ? y1 - c : y1);
    if (br) d += " L " + r(x1 - c) + " " + r(y1);
    d += " L " + r(bl ? x0 + c : x0) + " " + r(y1);
    if (bl) d += " L " + r(x0) + " " + r(y1 - c);
    d += " L " + r(x0) + " " + r(tl ? y0 + c : y0);
    if (tl) d += " L " + r(x0 + c) + " " + r(y0);
    d += " Z";
    return d;
}

// Flat-top hexagon fitted into w x h. `cut` is the horizontal length of the slanted sides
// (defaults to h/2 * tan(30deg) -> regular-looking hex).
function hexagon(w, h, cut, inset) {
    inset = inset || 0;
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    const hh = (y1 - y0) / 2;
    if (cut === undefined) cut = hh * Math.tan(Math.PI / 6);
    cut = Math.min(cut, (x1 - x0) / 2);
    const cy = y0 + hh;
    return "M " + r(x0 + cut) + " " + r(y0) +
        " L " + r(x1 - cut) + " " + r(y0) +
        " L " + r(x1) + " " + r(cy) +
        " L " + r(x1 - cut) + " " + r(y1) +
        " L " + r(x0 + cut) + " " + r(y1) +
        " L " + r(x0) + " " + r(cy) + " Z";
}

// Pointy-top hexagon centred at (cx, cy) with circumradius rad.
function hexPip(cx, cy, rad) {
    let d = "";
    for (let i = 0; i < 6; i++) {
        const a = -Math.PI / 2 + Math.PI * i / 3;
        d += (i === 0 ? "M " : " L ") + r(cx + rad * Math.cos(a)) + " " + r(cy + rad * Math.sin(a));
    }
    return d + " Z";
}

// Bar segment: parallelogram with ends slanted by `slant` px (30deg at height h -> h * tan(30)).
// `ends`: "both" (default), "left", "right", "none".
function slantedSegment(w, h, slant, ends, inset) {
    inset = inset || 0;
    ends = ends || "both";
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    if (slant === undefined) slant = (y1 - y0) * Math.tan(Math.PI / 6);
    const l = ends === "both" || ends === "left" ? slant : 0;
    const rt = ends === "both" || ends === "right" ? slant : 0;
    return "M " + r(x0 + l) + " " + r(y0) +
        " L " + r(x1) + " " + r(y0) +
        " L " + r(x1 - rt) + " " + r(y1) +
        " L " + r(x0) + " " + r(y1) + " Z";
}

// Arc from angle a0 to a1 (radians, 0 = +x, clockwise positive in screen coords).
function arc(cx, cy, rad, a0, a1) {
    const sx = cx + rad * Math.cos(a0), sy = cy + rad * Math.sin(a0);
    const ex = cx + rad * Math.cos(a1), ey = cy + rad * Math.sin(a1);
    const large = Math.abs(a1 - a0) > Math.PI ? 1 : 0;
    const sweep = a1 > a0 ? 1 : 0;
    return "M " + r(sx) + " " + r(sy) + " A " + r(rad) + " " + r(rad) + " 0 " + large + " " + sweep + " " + r(ex) + " " + r(ey);
}

// Corner ticks for a chamfered frame: short L-shaped strokes just inside the two square corners.
function cornerTicks(w, h, len, inset) {
    inset = inset || 0;
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    // top-right and bottom-left are the square corners in the default chamfer (tl + br cut)
    return "M " + r(x1 - len) + " " + r(y0 + 2) + " L " + r(x1 - 2) + " " + r(y0 + 2) + " L " + r(x1 - 2) + " " + r(y0 + len) +
        " M " + r(x0 + 2) + " " + r(y1 - len) + " L " + r(x0 + 2) + " " + r(y1 - 2) + " L " + r(x0 + len) + " " + r(y1 - 2);
}

// 3-segment zigzag divider across width w at height h.
function zigzag(w, h, segments) {
    segments = segments || 3;
    const step = w / segments;
    let d = "M 0 " + r(h / 2);
    for (let i = 0; i < segments; i++) {
        const x = step * (i + 0.5);
        d += " L " + r(x) + " " + (i % 2 === 0 ? 0 : r(h));
        d += " L " + r(step * (i + 1)) + " " + r(h / 2);
    }
    return d;
}
