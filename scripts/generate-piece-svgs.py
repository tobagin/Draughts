#!/usr/bin/env python3
"""Generate the 16 draughts piece SVGs (4 themes x red/black x checker/king).

Output goes to data/. Run from anywhere:
    python3 scripts/generate-piece-svgs.py
"""

import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "data")

C = 512          # center
R_EDGE = 430     # outer disc radius
R_TOP = 400      # top face radius


def ring(r, stroke, width, opacity):
    return (f'<circle cx="{C}" cy="{C}" r="{r}" fill="none" '
            f'stroke="{stroke}" stroke-width="{width}" stroke-opacity="{opacity}"/>')


def grooves(dark, light):
    """Two embossed concentric grooves like a turned piece."""
    out = []
    for r in (336, 296):
        out.append(ring(r, dark, 7, 0.45))
        out.append(ring(r - 5, light, 4, 0.35))
    return "\n".join(out)


def drop_shadow():
    return f'''<defs>
  <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%">
    <feGaussianBlur stdDeviation="18"/>
  </filter>
</defs>
<circle cx="{C + 10}" cy="{C + 22}" r="{R_EDGE}" fill="#000" opacity="0.35" filter="url(#shadow)"/>'''


def gloss(opacity=0.4):
    """Soft specular highlight, top-left."""
    return f'''<defs>
  <radialGradient id="gloss" cx="0.36" cy="0.28" r="0.55">
    <stop offset="0" stop-color="#fff" stop-opacity="{opacity}"/>
    <stop offset="0.55" stop-color="#fff" stop-opacity="{opacity * 0.35}"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
</defs>
<circle cx="{C}" cy="{C}" r="{R_TOP}" fill="url(#gloss)"/>'''


def crescent(opacity=0.5):
    """Crisp curved highlight along the upper-left of the top face."""
    r = R_TOP - 38
    return f'''<defs>
  <filter id="cresblur" x="-20%" y="-20%" width="140%" height="140%">
    <feGaussianBlur stdDeviation="7"/>
  </filter>
</defs>
<path d="M {C - r * 0.83:.0f} {C - r * 0.42:.0f} A {r} {r} 0 0 1 {C - r * 0.10:.0f} {C - r * 0.92:.0f}"
      fill="none" stroke="#fff" stroke-opacity="{opacity}" stroke-width="22"
      stroke-linecap="round" filter="url(#cresblur)"/>'''


def crown():
    """Gold crown shared by all king variants."""
    return f'''<defs>
  <linearGradient id="gold" x1="0" y1="0.3" x2="0" y2="1">
    <stop offset="0" stop-color="#f6dd8d"/>
    <stop offset="0.45" stop-color="#d9b545"/>
    <stop offset="1" stop-color="#8f6f1c"/>
  </linearGradient>
  <filter id="crownshadow" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="8"/>
  </filter>
</defs>
<g transform="translate(0,6)" opacity="0.4" filter="url(#crownshadow)">
  <path d="M 372 614 L 348 462 L 442 540 L 512 432 L 582 540 L 676 462 L 652 614 Z" fill="#000"/>
</g>
<g stroke="#6e5512" stroke-width="6" stroke-linejoin="round">
  <path d="M 372 614 L 348 462 L 442 540 L 512 432 L 582 540 L 676 462 L 652 614 Z" fill="url(#gold)"/>
  <rect x="366" y="614" width="292" height="42" rx="12" fill="url(#gold)"/>
  <circle cx="348" cy="444" r="20" fill="url(#gold)"/>
  <circle cx="512" cy="412" r="23" fill="url(#gold)"/>
  <circle cx="676" cy="444" r="20" fill="url(#gold)"/>
</g>
<path d="M 388 600 L 370 492" stroke="#fff" stroke-opacity="0.45" stroke-width="8" stroke-linecap="round"/>
<rect x="380" y="622" width="120" height="10" rx="5" fill="#fff" opacity="0.3"/>'''


def svg(body):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            'viewBox="0 0 1024 1024">\n' + body + "\n</svg>\n")


# ---------------------------------------------------------------- plastic

def plastic(colors, king):
    edge_hi, edge_lo, top_hi, top_mid, top_lo, groove_d, groove_l = colors
    body = f'''{drop_shadow()}
<defs>
  <linearGradient id="edge" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{edge_hi}"/>
    <stop offset="1" stop-color="{edge_lo}"/>
  </linearGradient>
  <radialGradient id="top" cx="0.38" cy="0.32" r="0.85">
    <stop offset="0" stop-color="{top_hi}"/>
    <stop offset="0.55" stop-color="{top_mid}"/>
    <stop offset="1" stop-color="{top_lo}"/>
  </radialGradient>
</defs>
<circle cx="{C}" cy="{C}" r="{R_EDGE}" fill="url(#edge)"/>
<circle cx="{C}" cy="{C}" r="{R_TOP}" fill="url(#top)"/>
{grooves(groove_d, groove_l)}
{gloss(0.42)}
{crescent(0.55)}'''
    if king:
        body += "\n" + crown()
    return svg(body)


# ------------------------------------------------------------------- wood

def wood(colors, king, seed):
    edge_hi, edge_lo, top_hi, top_mid, top_lo, grain_col, groove_d, groove_l = colors
    rings = []
    for i, r in enumerate(range(60, R_TOP - 20, 46)):
        rings.append(ring(r, "#000", 10, 0.05 + 0.02 * (i % 3)))
    annual = "\n".join(rings)
    body = f'''{drop_shadow()}
<defs>
  <linearGradient id="edge" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{edge_hi}"/>
    <stop offset="1" stop-color="{edge_lo}"/>
  </linearGradient>
  <radialGradient id="top" cx="0.42" cy="0.36" r="0.9">
    <stop offset="0" stop-color="{top_hi}"/>
    <stop offset="0.6" stop-color="{top_mid}"/>
    <stop offset="1" stop-color="{top_lo}"/>
  </radialGradient>
  <filter id="grain" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.0035 0.028" numOctaves="3" seed="{seed}" result="noise"/>
    <feColorMatrix in="noise" type="matrix"
      values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  1.6 1.6 1.6 0 -1.45"/>
    <feComposite operator="in" in2="SourceGraphic"/>
  </filter>
  <clipPath id="topclip"><circle cx="{C}" cy="{C}" r="{R_TOP}"/></clipPath>
</defs>
<circle cx="{C}" cy="{C}" r="{R_EDGE}" fill="url(#edge)"/>
<circle cx="{C}" cy="{C}" r="{R_TOP}" fill="url(#top)"/>
<g clip-path="url(#topclip)">
  <rect x="0" y="0" width="1024" height="1024" fill="{grain_col}" opacity="0.7" filter="url(#grain)"/>
  {annual}
</g>
{grooves(groove_d, groove_l)}
{gloss(0.16)}'''
    if king:
        body += "\n" + crown()
    return svg(body)


# ------------------------------------------------------------------ metal

def metal(colors, king):
    edge_hi, edge_lo, top_hi, top_mid, top_lo = colors
    rings = []
    for i, r in enumerate(range(36, R_TOP - 12, 7)):
        if i % 2 == 0:
            op = 0.07 + 0.10 * ((i * 7) % 5) / 4
            rings.append(ring(r, "#fff", 4, f"{op:.3f}"))
        else:
            op = 0.09 + 0.11 * ((i * 5) % 4) / 3
            rings.append(ring(r, "#000", 4, f"{op:.3f}"))
    brushed = "\n".join(rings)
    body = f'''{drop_shadow()}
<defs>
  <linearGradient id="edge" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{edge_hi}"/>
    <stop offset="1" stop-color="{edge_lo}"/>
  </linearGradient>
  <radialGradient id="top" cx="0.5" cy="0.5" r="0.72">
    <stop offset="0" stop-color="{top_hi}"/>
    <stop offset="0.62" stop-color="{top_mid}"/>
    <stop offset="1" stop-color="{top_lo}"/>
  </radialGradient>
  <linearGradient id="sheen" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.38"/>
    <stop offset="0.42" stop-color="#fff" stop-opacity="0"/>
    <stop offset="0.58" stop-color="#fff" stop-opacity="0"/>
    <stop offset="1" stop-color="#fff" stop-opacity="0.24"/>
  </linearGradient>
  <clipPath id="topclip"><circle cx="{C}" cy="{C}" r="{R_TOP}"/></clipPath>
</defs>
<circle cx="{C}" cy="{C}" r="{R_EDGE}" fill="url(#edge)"/>
<circle cx="{C}" cy="{C}" r="{R_TOP}" fill="url(#top)"/>
<g clip-path="url(#topclip)">
  {brushed}
  <circle cx="{C}" cy="{C}" r="{R_TOP}" fill="url(#sheen)"/>
</g>
{ring(R_TOP - 4, "#fff", 5, 0.22)}
{ring(R_EDGE - 6, "#000", 8, 0.3)}
{grooves("#000", "#fff")}'''
    if king:
        body += "\n" + crown()
    return svg(body)


# ------------------------------------------------------------- bottle-cap

def cap_path(n=21, r_peak=R_EDGE, r_valley=402):
    """Crimped bottle-cap outline: n flutes, smooth quadratic scallops."""
    pts = []
    step = 2 * math.pi / n
    for k in range(n):
        a0 = k * step - math.pi / 2
        am = a0 + step / 2
        a1 = a0 + step
        px0 = C + r_peak * math.cos(a0)
        py0 = C + r_peak * math.sin(a0)
        cx = C + (2 * r_valley - r_peak) * math.cos(am)
        cy = C + (2 * r_valley - r_peak) * math.sin(am)
        px1 = C + r_peak * math.cos(a1)
        py1 = C + r_peak * math.sin(a1)
        if k == 0:
            pts.append(f"M {px0:.1f} {py0:.1f}")
        pts.append(f"Q {cx:.1f} {cy:.1f} {px1:.1f} {py1:.1f}")
    pts.append("Z")
    return " ".join(pts)


def crimp_shading(n=21):
    """Alternating light/dark radial strokes over the fluted rim."""
    out = []
    step = 2 * math.pi / n
    for k in range(n):
        a = k * step - math.pi / 2 + step / 2
        x0 = C + 380 * math.cos(a)
        y0 = C + 380 * math.sin(a)
        x1 = C + (R_EDGE - 12) * math.cos(a)
        y1 = C + (R_EDGE - 12) * math.sin(a)
        out.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" '
                   f'stroke="#000" stroke-opacity="0.18" stroke-width="10" stroke-linecap="round"/>')
        ah = a - step * 0.25
        x0 = C + 384 * math.cos(ah)
        y0 = C + 384 * math.sin(ah)
        x1 = C + (R_EDGE - 16) * math.cos(ah)
        y1 = C + (R_EDGE - 16) * math.sin(ah)
        out.append(f'<line x1="{x0:.1f}" y1="{y0:.1f}" x2="{x1:.1f}" y2="{y1:.1f}" '
                   f'stroke="#fff" stroke-opacity="0.20" stroke-width="7" stroke-linecap="round"/>')
    return "\n".join(out)


def bottle_cap(colors, king):
    rim_hi, rim_lo, top_hi, top_mid, top_lo = colors
    body = f'''{drop_shadow()}
<defs>
  <radialGradient id="rim" cx="0.42" cy="0.36" r="0.85">
    <stop offset="0" stop-color="{rim_hi}"/>
    <stop offset="0.82" stop-color="{rim_hi}"/>
    <stop offset="1" stop-color="{rim_lo}"/>
  </radialGradient>
  <radialGradient id="top" cx="0.38" cy="0.32" r="0.85">
    <stop offset="0" stop-color="{top_hi}"/>
    <stop offset="0.55" stop-color="{top_mid}"/>
    <stop offset="1" stop-color="{top_lo}"/>
  </radialGradient>
</defs>
<path d="{cap_path()}" fill="url(#rim)"/>
{crimp_shading()}
<circle cx="{C}" cy="{C}" r="368" fill="url(#top)"/>
{ring(368, "#000", 6, 0.35)}
{ring(330, "#fff", 4, 0.25)}
{gloss(0.4)}
{crescent(0.5)}'''
    if king:
        body += "\n" + crown()
    return svg(body)


# ------------------------------------------------------------------ build

PLASTIC = {
    "red":   ("#7c1d14", "#54100a", "#d8493a", "#b03227", "#7e1f15", "#5e150d", "#e8736a"),
    "black": ("#3a3a42", "#0e0e12", "#45454d", "#26262c", "#101014", "#000000", "#6a6a74"),
}
WOOD = {
    "red":   ("#7a3320", "#4e1f12", "#a85638", "#8f4128", "#6b2c18", "#4a1d0e", "#3d1809", "#c87a55"),
    "black": ("#3a2d22", "#1e150e", "#4e3c2c", "#3a2b1e", "#261a10", "#140c06", "#0e0803", "#6e573e"),
}
METAL = {
    "red":   ("#7e211a", "#3e0c08", "#b04038", "#7e211a", "#4c100a"),
    "black": ("#34373c", "#101113", "#52565e", "#34373c", "#191b1e"),
}
CAP = {
    "red":   ("#a01225", "#4e0510", "#d8344c", "#c8102e", "#8c0a1f"),
    "black": ("#2e3138", "#0c0d10", "#3c4049", "#23262c", "#0f1013"),
}

GEN = {
    "":            (plastic, PLASTIC),
    "-wood":       (wood, WOOD),
    "-metal":      (metal, METAL),
    "-bottle-cap": (bottle_cap, CAP),
}

seed = 7
for suffix, (fn, palette) in GEN.items():
    for color in ("red", "black"):
        for kind in ("checker", "king"):
            king = kind == "king"
            if fn is wood:
                content = fn(palette[color], king, seed)
                seed += 11
            else:
                content = fn(palette[color], king)
            name = f"{color}-{kind}{suffix}.svg"
            with open(os.path.join(OUT, name), "w") as f:
                f.write(content)
            print("wrote", name)
