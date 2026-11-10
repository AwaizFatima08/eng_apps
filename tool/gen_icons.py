#!/usr/bin/env python3
"""Launcher icons for the Plant Tools apps (flat white glyph + amber accent on
the app's seed colour, matching LoopCal's gauge).

Writes apps/<app>/assets/icon/icon.png (full square) and icon_fg.png
(transparent, glyph scaled into the adaptive-icon safe zone).
Then run `dart run flutter_launcher_icons` in each app.
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = 2048  # supersampled canvas
WHITE = (255, 255, 255, 255)
AMBER = (255, 179, 0, 255)


def flask(d, bg):
    # Erlenmeyer flask: neck, conical body, amber liquid, drop above.
    neck_w, top, shoulder, base = 300, 330, 900, 1660
    cx = S // 2
    body = [(cx - neck_w // 2, shoulder), (cx - 640, base), (cx + 640, base),
            (cx + neck_w // 2, shoulder)]
    d.rectangle([cx - neck_w // 2, top, cx + neck_w // 2, shoulder], fill=WHITE)
    d.polygon(body, fill=WHITE)
    d.rounded_rectangle([cx - 230, top - 70, cx + 230, top + 40], 30, fill=WHITE)
    inset = 90
    liquid_top = 1180
    # liquid trapezoid inside the cone
    def x_at(y, side):
        t = (y - shoulder) / (base - shoulder)
        half = neck_w / 2 + t * (640 - neck_w / 2) - inset
        return cx + side * half
    d.polygon([(x_at(liquid_top, -1), liquid_top), (x_at(base - inset, -1), base - inset),
               (x_at(base - inset, 1), base - inset), (x_at(liquid_top, 1), liquid_top)],
              fill=AMBER)
    # inner hollow above liquid
    d.polygon([(cx - neck_w // 2 + inset, shoulder), (x_at(liquid_top, -1), liquid_top),
               (x_at(liquid_top, 1), liquid_top), (cx + neck_w // 2 - inset, shoulder)], fill=bg)
    d.rectangle([cx - neck_w // 2 + inset, top + 40, cx + neck_w // 2 - inset, shoulder], fill=bg)


def hard_hat(d, bg):
    cx, cy = S // 2, 1240
    d.pieslice([cx - 600, cy - 640, cx + 600, cy + 560], 180, 360, fill=WHITE)
    d.rounded_rectangle([cx - 820, cy - 40, cx + 820, cy + 130], 60, fill=WHITE)
    d.rounded_rectangle([cx - 110, cy - 700, cx + 110, cy - 60], 60, fill=AMBER)
    d.rounded_rectangle([cx - 820, cy + 240, cx + 820, cy + 340], 50, fill=AMBER)


def pipe(d, bg):
    y0, y1 = 820, 1230
    d.rectangle([330, y0, 1718, y1], fill=WHITE)
    for x in (330, 1590):
        d.rounded_rectangle([x - 40, y0 - 130, x + 168, y1 + 130], 30, fill=WHITE)
    # flow arrow below the pipe
    ay = 1530
    d.rectangle([520, ay - 55, 1380, ay + 55], fill=AMBER)
    d.polygon([(1340, ay - 190), (1600, ay), (1340, ay + 190)], fill=AMBER)
    # gap lines on the pipe body
    d.rectangle([900, y0, 940, y1], fill=bg)
    d.rectangle([1108, y0, 1148, y1], fill=bg)


def bolt(d, bg):
    cx, cy, r = S // 2, S // 2, 760
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=WHITE)
    d.ellipse([cx - r + 110, cy - r + 110, cx + r - 110, cy + r - 110], fill=bg)
    pts = [(1120, 330), (650, 1110), (980, 1110), (880, 1720), (1400, 900), (1060, 900), (1260, 330)]
    k = 0.72  # keep the bolt inside the ring
    d.polygon([(cx + (x - cx) * k, cy + (y - cy) * k) for x, y in pts], fill=AMBER)


def gear(d, bg):
    cx, cy = S // 2, S // 2
    teeth, r_out, r_in = 10, 800, 640
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4)
        r = r_out if (i % 4) in (1, 2) else r_in
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=WHITE)
    # amber hex nut in the centre
    hr = 360
    hexagon = [(cx + hr * math.cos(math.pi / 3 * k), cy + hr * math.sin(math.pi / 3 * k)) for k in range(6)]
    d.ellipse([cx - 470, cy - 470, cx + 470, cy + 470], fill=bg)
    d.polygon(hexagon, fill=AMBER)
    d.ellipse([cx - 150, cy - 150, cx + 150, cy + 150], fill=bg)


def ibeam(d, bg):
    cx = S // 2
    top, bot, fw, ft, ww = 820, 1500, 1300, 170, 190
    d.rectangle([cx - fw // 2, top, cx + fw // 2, top + ft], fill=WHITE)
    d.rectangle([cx - fw // 2, bot - ft, cx + fw // 2, bot], fill=WHITE)
    d.rectangle([cx - ww // 2, top, cx + ww // 2, bot], fill=WHITE)
    # amber load arrow onto the top flange
    d.rectangle([cx - 50, 330, cx + 50, 590], fill=AMBER)
    d.polygon([(cx - 170, 560), (cx + 170, 560), (cx, 760)], fill=AMBER)
    # supports
    for x in (cx - fw // 2 + 120, cx + fw // 2 - 120):
        d.polygon([(x, bot + 40), (x - 140, bot + 260), (x + 140, bot + 260)], fill=AMBER)


APPS = {
    'lab_toolkit': ('#7B3FA0', flask),
    'hse_toolkit': ('#B45309', hard_hat),
    'process_toolkit': ('#00796B', pipe),
    'electrical_toolkit': ('#3949AB', bolt),
    'mechanical_toolkit': ('#455A64', gear),
    'civil_toolkit': ('#8D4E2A', ibeam),
}


def render(draw_fn, bg, transparent):
    fill = (0, 0, 0, 0) if transparent else bg
    im = Image.new('RGBA', (S, S), bg if not transparent else fill)
    # Glyphs punch "holes" with bg colour; for the foreground layer draw on
    # the bg colour then key it out.
    if transparent:
        im = Image.new('RGBA', (S, S), bg)
    draw_fn(ImageDraw.Draw(im), bg)
    if transparent:
        px = im.load()
        for y in range(S):
            for x in range(S):
                if px[x, y] == bg:
                    px[x, y] = (0, 0, 0, 0)
    return im


def main():
    for app, (hexcol, fn) in APPS.items():
        bg = tuple(int(hexcol[i:i + 2], 16) for i in (1, 3, 5)) + (255,)
        out = os.path.join(ROOT, 'apps', app, 'assets', 'icon')
        os.makedirs(out, exist_ok=True)
        full = render(fn, bg, False).resize((1024, 1024), Image.LANCZOS).convert('RGB')
        full.save(os.path.join(out, 'icon.png'))
        fg = render(fn, bg, True).resize((1024, 1024), Image.LANCZOS)
        # scale glyph into the adaptive safe zone (~76 %), centred
        small = fg.resize((778, 778), Image.LANCZOS)
        canvas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
        canvas.paste(small, (123, 123), small)
        canvas.save(os.path.join(out, 'icon_fg.png'))
        print(app, 'ok')


if __name__ == '__main__':
    main()
