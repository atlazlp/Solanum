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

// Width/height of a regular flat-top hexagon (all six sides equal).
function hexAspect() {
    return 2 / Math.sqrt(3);
}

function hexWidthForHeight(h) {
    return h * hexAspect();
}

function hexHeightForWidth(w) {
    return w / hexAspect();
}

// Regular flat-top hexagon centred in w×h. Every side has the same length.
// `cut` is ignored (kept for call-site compatibility); sizing is always regular.
function hexagon(w, h, cut, inset) {
    inset = inset || 0;
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    const bw = Math.max(0, x1 - x0);
    const bh = Math.max(0, y1 - y0);
    // Side length s: width = 2s, height = √3 s.
    const s = Math.min(bw / 2, bh / Math.sqrt(3));
    const hh = s * Math.sqrt(3) / 2;
    const cx = (x0 + x1) / 2;
    const cy = (y0 + y1) / 2;
    return "M " + r(cx - s / 2) + " " + r(cy - hh) +
        " L " + r(cx + s / 2) + " " + r(cy - hh) +
        " L " + r(cx + s) + " " + r(cy) +
        " L " + r(cx + s / 2) + " " + r(cy + hh) +
        " L " + r(cx - s / 2) + " " + r(cy + hh) +
        " L " + r(cx - s) + " " + r(cy) + " Z";
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

// Vertical bar segment: parallelogram with top/bottom ends slanted (30deg at width w -> w * tan(30)).
// `ends`: "both" (default), "top", "bottom", "none".
// `radius`: softens the slanted corners (top-left / bottom-right) that do not carry corner ticks.
function slantedSegmentVertical(w, h, slant, ends, inset, radius) {
    inset = inset || 0;
    ends = ends || "both";
    radius = Math.max(0, radius || 0);
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    if (slant === undefined) slant = (x1 - x0) * Math.tan(Math.PI / 6);
    const t = ends === "both" || ends === "top" ? slant : 0;
    const b = ends === "both" || ends === "bottom" ? slant : 0;
    const bw = Math.max(1, x1 - x0);
    const topLen = Math.sqrt(bw * bw + t * t);
    const botLen = Math.sqrt(bw * bw + b * b);
    const radT = t > 0 ? Math.min(radius, t * 0.45, topLen * 0.35) : 0;
    const radB = b > 0 ? Math.min(radius, b * 0.45, botLen * 0.35) : 0;

    if (radT <= 0 && radB <= 0) {
        return "M " + r(x0) + " " + r(y0 + t) +
            " L " + r(x1) + " " + r(y0) +
            " L " + r(x1) + " " + r(y1 - b) +
            " L " + r(x0) + " " + r(y1) + " Z";
    }

    // Unit vectors along edges (screen coords, y down).
    const tUx = bw / topLen, tUy = -t / topLen;       // TL -> TR
    const bUx = -bw / botLen, bUy = b / botLen;       // BR -> BL

    let d = "";
    if (radT > 0) {
        // Start below TL on left edge, quadratic through TL onto top edge.
        d += "M " + r(x0) + " " + r(y0 + t + radT);
        d += " Q " + r(x0) + " " + r(y0 + t) + " " + r(x0 + tUx * radT) + " " + r(y0 + t + tUy * radT);
        d += " L " + r(x1) + " " + r(y0);
    } else {
        d += "M " + r(x0) + " " + r(y0 + t);
        d += " L " + r(x1) + " " + r(y0);
    }

    if (radB > 0) {
        d += " L " + r(x1) + " " + r(y1 - b - radB);
        d += " Q " + r(x1) + " " + r(y1 - b) + " " + r(x1 + bUx * radB) + " " + r(y1 - b + bUy * radB);
        d += " L " + r(x0) + " " + r(y1);
    } else {
        d += " L " + r(x1) + " " + r(y1 - b);
        d += " L " + r(x0) + " " + r(y1);
    }
    d += " Z";
    return d;
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

// Filled corner accents for a vertical parallelogram: small triangles on top-right + bottom-left.
// Vertices sit on the segment edges so nothing overflows the chamfered body.
function cornerFillsVertical(w, h, slant, ends, size, inset) {
    inset = inset || 0;
    ends = ends || "both";
    size = Math.max(2, size || 6);
    const x0 = inset, y0 = inset, x1 = w - inset, y1 = h - inset;
    if (slant === undefined) slant = (x1 - x0) * Math.tan(Math.PI / 6);
    const t = ends === "both" || ends === "top" ? slant : 0;
    const b = ends === "both" || ends === "bottom" ? slant : 0;
    const bw = Math.max(1, x1 - x0);

    function along(ux, uy, dist) {
        const L = Math.hypot(ux, uy) || 1;
        return [(ux / L) * dist, (uy / L) * dist];
    }

    // Top-right tip (x1, y0): along top toward TL, down the right.
    const [tux, tuy] = along(-bw, t, size);
    const tr = "M " + r(x1) + " " + r(y0) +
        " L " + r(x1 + tux) + " " + r(y0 + tuy) +
        " L " + r(x1) + " " + r(y0 + size) + " Z";

    // Bottom-left tip (x0, y1): up the left, along bottom toward BR.
    const [bux, buy] = along(bw, -b, size);
    const bl = "M " + r(x0) + " " + r(y1) +
        " L " + r(x0) + " " + r(y1 - size) +
        " L " + r(x0 + bux) + " " + r(y1 + buy) + " Z";

    return tr + " " + bl;
}

// Compat alias — bar segments use filled corners now.
function cornerTicksVertical(w, h, slant, ends, len, inset) {
    return cornerFillsVertical(w, h, slant, ends, len, inset);
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
