#!/usr/bin/env python3
# Draws the camera's app icon (camera-icon.svg): the legacy webOS camera's
# icon, rebuilt as vectors. Each part is a plain shape - the body, its brushed
# aluminium panel, the grip, the shutter button, the viewfinder, the light,
# the lens rings and glass, the engraving - with gradients whose colours are
# read from the legacy 256x256 icon (reference/app-icon-256x256.png), so the
# picture is the original's and the shapes stay clean at any size.
#
#   python3 -I tools/vectorize/camera-icon.py <PreludeWGL-Light.ttf> [out.svg]
#
# Needs Pillow and fontTools. The font is LuneOS's Prelude (webos-fonts); the
# engraving is its glyph outlines, so the SVG needs no font.
import math
import os
import sys

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REF = Image.open(os.path.join(HERE, "reference", "app-icon-256x256.png")).convert("RGBA")
FONT = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "..", "camera-icon.svg")

# Lens: the rings (centre x, centre y, radius), outermost first, then the glass;
# measured on the original, where each sits a little off the others' centre. The
# engraving sits on its own circle.
LX, LY = 150.9, 136.8
RINGS = [(150.9, 136.8, 56.0), (150.4, 138.3, 40.5), (151.1, 138.55, 32.75), (151.4, 139.3, 23.5)]

# The engraving's circle: the middle of the band between the lens's outer edge and the
# next ring, fitted over the arc the text covers.
TEXT = (150.65, 137.54, 48.24)

# The grip: standing a little proud of the body's left end, big round corners on the right.
GRIP = "M21,84.5 H46.5 A15,15 0 0,1 61.5,99.5 V167.5 A15,15 0 0,1 46.5,182.5 H21 A2,2 0 0,1 19,180.5 V86.5 A2,2 0 0,1 21,84.5 Z"


def ellrect(x, y, w, h, rx, ry):
    """a rectangle with elliptical corners"""
    return ("M%s,%s H%s A%s,%s 0 0,1 %s,%s V%s A%s,%s 0 0,1 %s,%s H%s A%s,%s 0 0,1 %s,%s V%s A%s,%s 0 0,1 %s,%s Z" % tuple(
        f(v) for v in (x + rx, y, x + w - rx, rx, ry, x + w, y + ry, y + h - ry, rx, ry, x + w - rx, y + h,
                       x + rx, rx, ry, x, y + h - ry, y + ry, rx, ry, x + rx, y)))


def px(x, y):
    return REF.getpixel((int(x), int(y)))


def sample(x, y):
    """bilinear colour at (x, y), pixel centres at +0.5"""
    x, y = x - 0.5, y - 0.5
    x0, y0 = int(math.floor(x)), int(math.floor(y))
    fx, fy = x - x0, y - y0
    out = [0.0, 0.0, 0.0]
    for dx, dy, w in ((0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)):
        c = REF.getpixel((x0 + dx, y0 + dy))
        for k in range(3):
            out[k] += c[k] * w
    return tuple(out)


def f(v):
    s = "%.3f" % v
    s = s.rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def hexc(c):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in c[:3])


def smooth(vals, k):
    out = []
    for i in range(len(vals)):
        win = vals[max(0, i - k):i + k + 1]
        out.append(tuple(sum(w[j] for w in win) / len(win) for j in range(len(vals[0]))))
    return out


class Doc:
    def __init__(self):
        self.defs, self.body, self.n = [], [], 0

    def gid(self, p="g"):
        self.n += 1
        return "%s%d" % (p, self.n)

    def linear(self, x1, y1, x2, y2, stops):
        """stops: (offset, rgb, opacity)"""
        g = self.gid()
        s = "".join('<stop offset="%s" stop-color="%s"%s/>' % (f(o), hexc(c), "" if a >= 0.999 else ' stop-opacity="%s"' % f(a))
                    for o, c, a in stops)
        self.defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>'
                         % (g, f(x1), f(y1), f(x2), f(y2), s))
        return "url(#%s)" % g

    def radial(self, cx, cy, r, stops, fx=None, fy=None):
        g = self.gid()
        s = "".join('<stop offset="%s" stop-color="%s"%s/>' % (f(o), hexc(c), "" if a >= 0.999 else ' stop-opacity="%s"' % f(a))
                    for o, c, a in stops)
        foc = "" if fx is None else ' fx="%s" fy="%s"' % (f(fx), f(fy))
        self.defs.append('<radialGradient id="%s" gradientUnits="userSpaceOnUse" cx="%s" cy="%s" r="%s"%s>%s</radialGradient>'
                         % (g, f(cx), f(cy), f(r), foc, s))
        return "url(#%s)" % g

    def blur(self, sd):
        g = self.gid("b")
        self.defs.append('<filter id="%s" x="-20%%" y="-20%%" width="140%%" height="140%%"><feGaussianBlur stdDeviation="%s"/></filter>'
                         % (g, f(sd)))
        return "url(#%s)" % g

    def add(self, s):
        self.body.append(s)

    def svg(self):
        return ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">'
                "<defs>%s</defs>%s</svg>\n" % ("".join(self.defs), "".join(self.body)))


def rrect(x, y, w, h, tl, tr=None, br=None, bl=None):
    tr = tl if tr is None else tr
    br = tl if br is None else br
    bl = tl if bl is None else bl
    return ("M%s,%s H%s A%s,%s 0 0,1 %s,%s V%s A%s,%s 0 0,1 %s,%s H%s A%s,%s 0 0,1 %s,%s V%s A%s,%s 0 0,1 %s,%s Z" % tuple(
        f(v) for v in (x + tl, y, x + w - tr, tr, tr, x + w, y + tr, y + h - br, br, br, x + w - br, y + h,
                       x + bl, bl, bl, x, y + h - bl, y + tl, tl, tl, x + tl, y)))


def circle(cx, cy, r):
    return "M%s,%s A%s,%s 0 1,1 %s,%s A%s,%s 0 1,1 %s,%s Z" % tuple(f(v) for v in (cx - r, cy, r, r, cx + r, cy, r, r, cx - r, cy))


def column(x, y0, y1, step=1.0):
    """colours down a column, as gradient stops from y0 to y1"""
    ys = [y0 + i * step for i in range(int((y1 - y0) / step) + 1)]
    return [((y - y0) / (y1 - y0), px(x, y), 1.0) for y in ys]


def row(y, x0, x1, step=1.0):
    xs = [x0 + i * step for i in range(int((x1 - x0) / step) + 1)]
    return [((x - x0) / (x1 - x0), px(x, y), 1.0) for x in xs]


class _ArcPen:
    """Passes outlines on to another pen with every point bent round a circle."""

    def __init__(self, pen, warp):
        self.pen, self.warp = pen, warp

    def _w(self, pts):
        return [None if p is None else self.warp(p) for p in pts]

    def moveTo(self, p):
        self.pen.moveTo(self.warp(p))

    def lineTo(self, p):
        self.pen.lineTo(self.warp(p))

    def curveTo(self, *pts):
        self.pen.curveTo(*self._w(pts))

    def qCurveTo(self, *pts):
        self.pen.qCurveTo(*self._w(pts))

    def closePath(self):
        self.pen.closePath()

    def endPath(self):
        self.pen.endPath()

    def addComponent(self, name, transform):
        raise NotImplementedError


def arc_text(text, cx, cy, rb, size, theta_c, tracking):
    """Text on a circle: the baseline is the circle of radius rb, tops outward, running
    clockwise and centred on theta_c (degrees). Every point of every glyph is bent onto
    the circle, so the letters follow it rather than standing on straight chords."""
    font = TTFont(FONT)
    gs, cmap, upm = font.getGlyphSet(), font.getBestCmap(), font["head"].unitsPerEm
    s = size / upm
    names = [cmap.get(ord(ch), ".notdef") for ch in text]
    adv = [gs[n].width * s + tracking * size for n in names]
    start = math.radians(theta_c) - (sum(adv) - tracking * size) / rb / 2
    out, pos = [], 0.0
    for n, a in zip(names, adv):
        def warp(p, pos=pos):
            th = start + (pos + p[0] * s) / rb
            r = rb + p[1] * s
            return (cx + r * math.cos(th), cy + r * math.sin(th))
        pen = SVGPathPen(gs, ntos=f)
        gs[n].draw(_ArcPen(pen, warp))
        out.append(pen.getCommands())
        pos += a
    return " ".join(o for o in out if o)


def main():
    d = Doc()
    # The body, as the original's outline measures: a flat top with small corners,
    # sides narrowing a little toward the bottom, and wide, shallow bottom corners where
    # the base curves round. The panel runs between the lid and the base, side to side.
    BODY = "M25.2,59.2 H232.4 A4.8,2.5 0 0,1 237.2,61.7 L234,195 A15,10 0 0,1 219,205 H39 A15,10 0 0,1 24,195 L20.8,61.7 A4.4,2.5 0 0,1 25.2,59.2 Z"
    PANEL = "M21.18,69.5 H236.82 L234.2,191.5 Q234,196.3 222,196.4 H36 Q24,196.3 23.8,191.5 Z"
    bodymask = d.gid("m")
    d.defs.append('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256"><path d="%s" fill="#fff"/></mask>' % (bodymask, BODY))

    # The disc of light behind the camera: white, fading downward, soft edged.
    # (its lower half read clear of the body's shadow)
    # A crisp disc, a soft dark shadow all round its edge, and a thin light rim.
    HC, HR = 127.5, 112.0
    ring = []
    for i in range(0, 15):            # the shadow, read outside the edge on the left
        a = REF.getpixel((int(HC - HR) - 1 - i, 128))[3] / 255.0
        ring.append(((HR + 0.5 + i) / (HR + 15), (0, 0, 0), a))
    d.add('<path d="%s" fill="%s"/>' % (circle(HC, HC, HR + 15), d.radial(HC, HC, HR + 15, [(0, (0, 0, 0), 0.0), (HR / (HR + 15), (0, 0, 0), 0.0)] + ring + [(1, (0, 0, 0), 0.0)])))
    # Its light is strongest toward the rim and fades toward the middle (as the original
    # measures round (127.5, 129)), and the whole disc fades out downward, behind and
    # below the camera.
    fade = d.gid("m")
    d.defs.append('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256"><rect width="256" height="256" fill="%s"/></mask>'
                  % (fade, d.linear(0, 90, 0, 215, [(0, (255, 255, 255), 1.0), (1, (0, 0, 0), 1.0)])))
    disc = [(0, 0.0), (62, 0.0), (74, 0.26), (84, 0.35), (90, 0.38), (97, 0.40), (HR, 0.40)]
    d.add('<g mask="url(#%s)">' % fade)
    d.add('<path d="%s" fill="%s"/>' % (circle(HC, HC, HR), d.radial(HC, 129, HR + 1.5, [(r / (HR + 1.5), (255, 255, 255), a) for r, a in disc])))
    d.add('<path d="%s" fill="none" stroke="#fff" stroke-opacity="0.18" stroke-width="1"/>' % circle(HC, HC, HR - 0.5))
    d.add('</g>')

    # Drop shadow under the body.
    d.add('<path d="%s" fill="#000" fill-opacity="0.8" transform="translate(0 3)" filter="%s"/>'
          % (BODY, d.blur(2.6)))

    # Shutter button, rising out of the body's top: a flange, and on it a cap with
    # sloping sides; chrome, each with a lit rim along its top.
    flange = "M66.4,59 L68,56.4 Q68.4,55.8 69.2,55.8 H96.8 Q97.6,55.8 98,56.4 L99.6,59 Z"
    d.add('<path d="%s" fill="%s"/>' % (flange, d.linear(67, 0, 99, 0, row(58, 67, 99, 1.0))))
    d.add('<path d="%s" fill="%s"/>' % (flange, d.linear(0, 55.8, 0, 58, [(0, (255, 255, 255), 0.75), (0.45, (255, 255, 255), 0.15), (1, (255, 255, 255), 0.0)])))
    cap = "M71.2,56 L73.2,52 Q73.6,51.3 74.8,51.2 Q83,49.7 91.2,51.2 Q92.4,51.3 92.8,52 L94.8,56 Z"
    d.add('<path d="%s" fill="%s"/>' % (cap, d.linear(71, 0, 95, 0, row(54, 71, 95, 1.0))))
    d.add('<path d="%s" fill="%s"/>' % (cap, d.linear(0, 50, 0, 54, [(0, (255, 255, 255), 0.4), (0.5, (255, 255, 255), 0.95), (0.8, (255, 255, 255), 0.2), (1, (255, 255, 255), 0.0)])))

    # Body: silver, lit from above; its top and bottom bands are what shows round the panel.
    top = column(120, 59.5, 70, 0.5)
    bot = column(120, 194, 204, 0.5)
    # (the base's colour reaches up into the bottom corners, where the panel curves away)
    stops = ([((59.5 + o * 10.5 - 59.3) / 145.2, c, 1.0) for o, c, _ in top] + [((190 - 59.3) / 145.2, px(120, 198), 1.0)]
             + [((194 + o * 10 - 59.3) / 145.2, c, 1.0) for o, c, _ in bot])
    d.add('<path d="%s" fill="%s"/>' % (BODY, d.linear(0, 59.3, 0, 204.5, stops)))

    # The panel: dark anodised aluminium, its light down the rows taken left of the lens,
    # without the brushing (a running median over the row).
    rows = []
    for y in range(70, 196):
        vals = sorted(REF.getpixel((x, y))[:3] for x in range(64, 92) if not (74 < x < 91 and 84 < y < 101))
        rows.append(vals[len(vals) // 2] if vals else rows[-1])
    rows = smooth(rows, 2)
    stops = [((y - 69.5) / 126.0, c, 1.0) for y, c in zip(range(70, 196), rows)][::2]
    d.add('<path d="%s" fill="%s"/>' % (PANEL, d.linear(0, 69.5, 0, 195.5, stops)))
    # ... darker toward its right end, where it turns away from the light
    ref = sum(sum(REF.getpixel((x, 180))[:3]) for x in range(64, 92)) / (3.0 * 28)
    st = []
    for x in range(196, 237, 2):
        v = sum(REF.getpixel((x, 180))[:3]) / 3.0
        st.append(((x - 196) / 40.0, (0, 0, 0), max(0.0, min(1.0, 1 - v / ref))))
    d.add('<g mask="url(#%s)">' % bodymask)
    d.add('<rect x="196" y="69.5" width="42" height="126" fill="%s"/>' % d.linear(196, 0, 236, 0, st))

    # Brushing: hairlines along the rows, across the whole panel (the parts on it cover
    # them). Their lengths and the gaps between them are the original's, measured where
    # its panel shows; laid out with a fixed seed, so the icon comes out the same each time.
    import random
    lum = [[sum(REF.getpixel((x, y))[:3]) / 3.0 for x in range(256)] for y in range(256)]
    runs, gaps = {1: [], -1: []}, []
    for y in range(72, 84):          # the strip above the grip, light and lens, clear of them all
        line = lum[y]
        mean = [sum(line[max(0, x - 12):x + 13]) / len(line[max(0, x - 12):x + 13]) for x in range(256)]
        x, last = 64, 64
        while x < 190:
            sign = 1 if line[x] - mean[x] > 2.0 else -1 if line[x] - mean[x] < -2.0 else 0
            if sign:
                x0 = x
                while x < 190 and sign * (line[x] - mean[x]) > 2.0:
                    x += 1
                if x - x0 >= 3:
                    runs[sign].append(x - x0)
                    gaps.append(x0 - last)
                    last = x
            else:
                x += 1
    rnd = random.Random(1)
    nl, nd = len(runs[1]), len(runs[-1])
    light, dark = [], []
    for y in range(70, 196):
        x = 18 + rnd.choice(gaps)
        while x < 238:
            sign = 1 if rnd.random() < nl / float(nl + nd) else -1
            n = min(2 * rnd.choice(runs[sign]), 238 - x)
            yy = y + rnd.random() * 0.6
            (light if sign > 0 else dark).append("M%d,%s h%d v0.4 h-%d Z" % (x, f(yy), n, n))
            x += n + rnd.choice(gaps)
    d.add('<path d="%s" fill="#fff" fill-opacity="0.07"/>' % "".join(light))
    d.add('<path d="%s" fill="#000" fill-opacity="0.13"/>' % "".join(dark))

    # The body's rounded ends, where the panel, the lid and the base turn round: their
    # colours across the last few pixels, from the original.
    def ends(y0, y1, yl, yr, xl, xr):
        d.add('<rect x="20" y="%s" width="8" height="%s" fill="%s"/>' % (f(y0), f(y1 - y0), d.linear(xl, 0, xl + 7, 0, [
            (k / 7.0, px(xl + k, yl), 1.0 - (k / 7.0) ** 2) for k in range(8)])))
        d.add('<rect x="229" y="%s" width="9" height="%s" fill="%s"/>' % (f(y0), f(y1 - y0), d.linear(xr - 7, 0, xr, 0, [
            (k / 7.0, px(xr - 7 + k, yr), 1.0 - ((7 - k) / 7.0) ** 2) for k in range(8)])))
    ends(69.5, 182, 77, 100, 21, 236)       # the panel (its lit left end stops at the grip's foot)
    ends(59, 69.5, 65, 65, 21, 236)         # the lid
    ends(195, 205, 199, 199, 24, 233)       # the base
    d.add('</g>')
    # the base's lit top edge, following the panel's bottom up into the corners
    d.add('<path d="M24,192.6 Q24.6,197.2 37,197.3 H221 Q233.4,197.2 234,192.6" fill="none" stroke-width="1.1" stroke="%s"/>' % d.linear(24, 0, 234, 0, [
        (0, (255, 255, 255), 0.85), (0.08, (255, 255, 255), 0.5), (0.15, (255, 255, 255), 0.25), (0.85, (255, 255, 255), 0.25), (0.92, (255, 255, 255), 0.5), (1, (255, 255, 255), 0.85)]))

    # Grip: shadow on the panel, then the grip, flush with the body's left end,
    # shaded across and lit from above.
    d.add('<path d="%s" fill="#000" fill-opacity="0.45" transform="translate(1.5 1)" filter="%s"/>'
          % (GRIP, d.blur(1.2)))
    grip = GRIP
    d.add('<path d="%s" fill="%s"/>' % (grip, d.linear(19, 0, 61.5, 0, row(140, 19, 61.5, 1.0))))
    mid = sum(px(40, 140)[:3]) / 3.0
    st = []
    for y in range(86, 182, 3):
        v = sum(px(40, y)[:3]) / 3.0
        st.append(((y - 84.5) / 98.0, (255, 255, 255) if v >= mid else (0, 0, 0), min(1.0, abs(v - mid) / 255.0 * 2.2)))
    d.add('<path d="%s" fill="%s"/>' % (grip, d.linear(0, 84.5, 0, 182.5, st)))
    d.add('<path d="%s" fill="%s"/>' % (grip, d.linear(0, 84.5, 0, 87, [(0, (255, 255, 255), 0.8), (1, (255, 255, 255), 0.0)])))

    # Viewfinder: a dark recess and its window.
    d.add('<path d="%s" fill="#000" fill-opacity="0.22"/>' % rrect(195, 77, 34, 16, 3))
    d.add('<path d="%s" fill="%s"/>' % (rrect(196, 78, 32, 14, 2.5), d.linear(0, 78, 0, 92, column(211, 78, 92, 1.0))))
    # ... and a glare across its glass
    glare = d.gid("m")
    d.defs.append('<mask id="%s" maskUnits="userSpaceOnUse" x="0" y="0" width="256" height="256"><path d="%s" fill="#fff"/></mask>' % (glare, rrect(196, 78, 32, 14, 2.5)))
    d.add('<path d="M203,78 L211,78 L205,92 L197,92 Z" fill="%s" mask="url(#%s)"/>' % (d.linear(197, 0, 211, 0, [
        (0, (255, 255, 255), 0.0), (0.5, (255, 255, 255), 0.55), (1, (255, 255, 255), 0.0)]), glare))
    d.add('<path d="M213,78 L216,78 L210,92 L207,92 Z" fill="#fff" fill-opacity="0.3" mask="url(#%s)"/>' % glare)

    # The light: a dark red bead in a dark rim, the sky reflected in its upper half.
    d.add('<path d="%s" fill="#000" fill-opacity="0.45" filter="%s"/>' % (circle(82, 92.6, 7.6), d.blur(0.7)))
    d.add('<path d="%s" fill="%s"/>' % (circle(82, 92, 7.4), hexc(px(74, 92))))
    d.add('<path d="%s" fill="%s"/>' % (circle(82, 92, 6.4), d.radial(82, 94, 7, [(0, px(81, 96), 1.0), (0.6, px(84, 94), 1.0), (1, px(76, 92), 1.0)])))
    cap = "M76.2,90.6 A6,6 0 0,1 87.8,90.6 Z"
    d.add('<path d="%s" fill="%s"/>' % (cap, d.linear(76, 0, 88, 0, row(88, 76, 88, 1.0))))
    d.add('<path d="%s" fill="%s"/>' % (cap, d.linear(0, 85, 0, 90.6, [(0, (0, 0, 0), 0.35), (0.6, (0, 0, 0), 0.0), (1, (255, 255, 255), 0.15)])))

    # Lens: its shadow on the body, the rings (each shows as the band outside the next),
    # the glass.
    d.add('<path d="%s" fill="#000" fill-opacity="0.5" transform="translate(0 2)" filter="%s"/>' % (circle(LX, LY, 56.5), d.blur(2.0)))
    # The rings telescope: each is a little off the others' centre, so the grooves between
    # them are wider at the bottom than at the top. Each ring is a bevel - a radial
    # gradient from its band on the lens's left, the middle of the light - with the light
    # from above as a ramp over it, and the groove inside it a dark line, deepest at the
    # bottom where the lens is turned away from the light.
    for i, ((cx, cy, r), (nx, ny, nr)) in enumerate(zip(RINGS[:-1], RINGS[1:])):
        st = []
        rr = nr - 0.5
        while rr <= r:
            st.append((rr / r, sample(cx - rr, cy + 0.5), 1.0))
            rr += 0.5
        d.add('<path d="%s" fill="%s"/>' % (circle(cx, cy, r), d.radial(cx, cy, r, st)))
        mid = (r + nr) / 2
        side = sum(sample(cx - mid, cy + 0.5)) / 3.0
        # (the light from above read near the ring's outer edge, clear of the engraving)
        topv, botv = sum(sample(cx, cy - (r - 1.5))) / 3.0, sum(sample(cx, cy + mid)) / 3.0
        tone = lambda v: ((255, 255, 255) if v > side else (0, 0, 0), min(1.0, abs(v - side) / (255.0 - side if v > side else side)))
        (ct, at), (cb, ab) = tone(topv), tone(botv)
        d.add('<path d="%s" fill="%s"/>' % (circle(cx, cy, r), d.linear(0, cy - r, 0, cy + r, [(0, ct, at), (0.5, (0, 0, 0), 0.0), (1, cb, ab)])))
        if i > 0:   # a step catches the light along its top
            d.add('<path d="%s" fill="none" stroke-width="1" stroke="%s"/>' % (circle(cx, cy, r - 0.5), d.linear(0, cy - r, 0, cy + r, [
                (0, (255, 255, 255), 0.85), (0.35, (255, 255, 255), 0.35), (0.6, (255, 255, 255), 0.0), (1, (255, 255, 255), 0.0)])))
        # the next ring stands up from this one and shades it, below more than above
        d.add('<path d="%s" fill="#000" fill-opacity="0.4" transform="translate(0.3 1.6)" filter="%s"/>' % (circle(nx, ny, nr), d.blur(1.4)))
    # the engraving, a shade darker than the ring it is cut into
    ring = px(LX, LY - 49)
    # Centred in the band between the outer edge and the next ring: the circle that best
    # fits that band's middle over the arc the text covers (the rings are not concentric,
    # so it is neither ring's centre), with the letters' cap height straddling it.
    font = TTFont(FONT)
    cap = font["OS/2"].sCapHeight / font["head"].unitsPerEm * 8.6
    text = arc_text("Camera \u2022 Camcorder", TEXT[0], TEXT[1], TEXT[2] - cap / 2, 8.6, -90, 0.035)
    d.add('<path d="%s" fill="%s" fill-opacity="0.85"/>' % (text, hexc(tuple(v * 0.8 for v in ring[:3]))))
    # The glass: a black bezel; inside it dark violet going to black in the middle, the
    # room behind reflected as a pink crescent along the bottom and a pale cyan one across
    # the top, and a spot of light.
    gx, gy, g = RINGS[-1]
    gi = g - 3.4
    d.add('<path d="%s" fill="#020102"/>' % circle(gx, gy, g))
    d.add('<path d="%s" fill="%s"/>' % (circle(gx, gy, gi), d.radial(gx, gy, gi, [
        (0, (4, 3, 4), 1.0), (0.25, (8, 4, 7), 1.0), (0.55, (44, 18, 38), 1.0), (0.8, (52, 30, 48), 1.0), (1, (40, 24, 38), 1.0)])))
    d.add('<path d="%s" fill="%s"/>' % (circle(gx, gy, gi), d.radial(gx, gy - 9, gi + 9.5, [
        (0, (195, 175, 192), 0.0), (0.7, (150, 90, 140), 0.0), (0.82, (140, 70, 125), 0.55), (0.93, (175, 145, 170), 0.85), (1, (200, 185, 198), 0.9)])))
    d.add('<path d="%s" fill="%s"/>' % (circle(gx, gy, gi), d.radial(gx, gy - 12.5, 11, [
        (0, (190, 205, 205), 0.95), (0.45, (150, 185, 185), 0.75), (0.8, (90, 140, 140), 0.35), (1, (60, 110, 110), 0.0)])))
    d.add('<path d="%s" fill="#fff" fill-opacity="0.85" filter="%s"/>' % (circle(gx - 0.5, gy - 13, 2.0), d.blur(0.7)))

    open(OUT, "w").write(d.svg())
    print("wrote", OUT, file=sys.stderr)


main()
