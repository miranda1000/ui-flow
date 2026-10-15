#!/usr/bin/env python3
"""render.py <inputs> <out-dir> [--icons <dir>] - composes the README banners from what
make-banners.sh captured: 2x screenshots of a 1440 x 900 ui-flow window (crop boxes below
are in window pixels), the example app's screens and its Markdown export.

Every banner is a rounded card with transparent corners, so it sits well on light and dark
pages. Drawing happens at twice the output size and is downsampled at the end."""
import json
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter, ImageFont

INTER = os.environ.get("UIFLOW_INTER_DIR", "/opt/deps/inter")
MONO_DIR = "/usr/share/fonts/truetype/dejavu"
S = 2    # screenshot pixels per window pixel
SS = 2   # drawing pixels per output pixel

INK, BODY, MUTED, LINE = "#16181D", "#525A66", "#8A93A0", "#DDE3EA"
ACCENT, ACCENT_SOFT = "#0D99FF", "#E5F4FF"
PURPLE, PURPLE_SOFT = "#9747FF", "#F3EBFF"
GREEN, WARN = "#14AE5C", "#D98A00"
BG_TOP, BG_BOTTOM, DOT = "#FBFCFE", "#EDF2F8", "#D3DCE7"

_fonts = {}


def font(size, weight="Regular"):
    key = (size, weight)
    if key not in _fonts:
        if weight in ("Mono", "MonoBold"):
            path = os.path.join(MONO_DIR, "DejaVuSansMono-Bold.ttf" if weight == "MonoBold" else "DejaVuSansMono.ttf")
        else:
            path = os.path.join(INTER, f"Inter-{weight}.ttf")
        _fonts[key] = ImageFont.truetype(path, round(size * SS))
    return _fonts[key]


def rgba(color, alpha=1.0):
    return ImageColor.getrgb(color)[:3] + (round(alpha * 255),)


def rounded_mask(size, radius, ss=3):
    w, h = size
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w * ss - 1, h * ss - 1), round(radius * ss), fill=255)
    return m.resize(size, Image.LANCZOS)


def round_corners(img, radius):
    img = img.convert("RGBA")
    img.putalpha(ImageChops.multiply(img.getchannel("A"), rounded_mask(img.size, radius)))
    return img


class Icons:
    """The app's own SVG icons (black strokes), rasterised with rsvg-convert and tinted."""

    def __init__(self, folder):
        self.folder = folder
        self.tmp = tempfile.mkdtemp(prefix="banner-icons-")

    def get(self, name, px, color):
        out = os.path.join(self.tmp, f"{name}-{px}.png")
        if not os.path.exists(out):
            subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", out,
                            os.path.join(self.folder, name + ".svg")], check=True)
        icon = Image.open(out).convert("RGBA")
        if color is None:  # keep its own colours (the app icon)
            return icon
        tinted = Image.new("RGBA", icon.size, rgba(color))
        tinted.putalpha(icon.getchannel("A"))
        return tinted


class Placed:
    """Where a screenshot crop ended up: maps window pixels to banner coordinates."""

    def __init__(self, x, y, scale, box):
        self.x, self.y, self.scale, self.box = x, y, scale, box

    def __call__(self, wx, wy):
        return (self.x + (wx - self.box[0]) * S * self.scale, self.y + (wy - self.box[1]) * S * self.scale)


class Banner:
    def __init__(self, w, h, glows=()):
        self.w, self.h = w, h
        W, H = w * SS, h * SS
        grad = Image.linear_gradient("L").resize((W, H))
        self.img = Image.composite(Image.new("RGBA", (W, H), BG_BOTTOM), Image.new("RGBA", (W, H), BG_TOP), grad)
        self._dots()
        for g in glows:
            self.glow(*g)
        self.d = ImageDraw.Draw(self.img)

    @staticmethod
    def p(*v):
        return [round(x * SS) for x in v]

    def _dots(self, step=26, r=1.5):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        for y in range(step // 2, self.h, step):
            for x in range(step // 2, self.w, step):
                d.ellipse(self.p(x - r, y - r, x + r, y + r), fill=rgba(DOT, 0.75))
        self.img.alpha_composite(layer)

    def glow(self, cx, cy, r, color, alpha):
        k = 8  # computed at 1/k resolution, then upscaled: it is a blur anyway
        small = Image.new("L", (self.w * SS // k, self.h * SS // k), 0)
        c, rr = (cx * SS / k, cy * SS / k), r * SS / k
        ImageDraw.Draw(small).ellipse((c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr), fill=round(255 * alpha))
        mask = small.filter(ImageFilter.GaussianBlur(rr * 0.45)).resize(self.img.size, Image.BICUBIC)
        layer = Image.new("RGBA", self.img.size, rgba(color))
        layer.putalpha(mask)
        self.img.alpha_composite(layer)

    def paste(self, im, x, y):
        self.img.paste(im, (round(x * SS), round(y * SS)), im)

    def shadow(self, x, y, w, h, radius, blur=34, alpha=0.16, dy=18, mask=None):
        pad = blur * 3
        if mask is None:
            m = Image.new("L", self.p(w + 2 * pad, h + 2 * pad), 0)
            ImageDraw.Draw(m).rounded_rectangle(self.p(pad, pad, pad + w, pad + h), radius * SS, fill=255)
        else:  # alpha of an arbitrary (e.g. rotated) image, already at drawing scale
            m = Image.new("L", (mask.width + 2 * pad * SS, mask.height + 2 * pad * SS), 0)
            m.paste(mask, (pad * SS, pad * SS))
        for b, a, oy in ((blur, alpha, dy), (4, alpha * 0.5, 2)):
            blurred = m.filter(ImageFilter.GaussianBlur(b * SS / 2))
            layer = Image.new("RGBA", m.size, rgba("#101828"))
            layer.putalpha(blurred.point(lambda v, a=a: round(v * a)))
            self.paste(layer, x - pad, y - pad + oy)

    def card(self, im, x, y, width, radius=18, border=LINE, shadow=0.16, box=(0, 0)):
        """Pastes a screenshot crop scaled to `width` with rounded corners and a shadow."""
        scale = width * SS / im.width
        h = im.height * scale / SS
        if shadow:
            self.shadow(x, y, width, h, radius, alpha=shadow)
        scaled = round_corners(im.resize((round(width * SS), round(h * SS)), Image.LANCZOS), radius * SS)
        self.paste(scaled, x, y)
        if border:
            self.outline(x, y, width, h, radius, border)
        return Placed(x, y, scale / SS, box)

    def shot(self, inputs, name, box, x, y, width, **kw):
        im = Image.open(os.path.join(inputs, name + ".png")).convert("RGBA")
        crop = im.crop(tuple(v * S for v in box))
        return self.card(crop, x, y, width, box=box, **kw)

    def outline(self, x, y, w, h, radius, color, width=1.5):
        ss = 2
        pw, ph = round(w * SS * ss), round(h * SS * ss)
        layer = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
        ImageDraw.Draw(layer).rounded_rectangle((0, 0, pw - 1, ph - 1), round(radius * SS * ss), outline=rgba(color),
                                                width=round(width * SS * ss))
        self.paste(layer.resize((round(w * SS), round(h * SS)), Image.LANCZOS), x, y)

    # --- Text ---

    def text(self, x, y, s, size, weight="Regular", color=INK, anchor="la"):
        self.d.text(self.p(x, y), s, font=font(size, weight), fill=color, anchor=anchor)

    def width_of(self, s, size, weight="Regular"):
        return self.d.textlength(s, font=font(size, weight)) / SS

    def lines(self, s, size, weight, width):
        out, line = [], ""
        for word in s.split():
            candidate = (line + " " + word).strip()
            if line and self.width_of(candidate, size, weight) > width:
                out.append(line)
                line = word
            else:
                line = candidate
        return out + [line]

    def spaced(self, x, y, s, size, weight, color, tracking):
        for ch in s:
            self.text(x, y, ch, size, weight, color)
            x += self.width_of(ch, size, weight) + tracking
        return x

    def text_block(self, x, width, eyebrow, title, body, how=(), color=ACCENT, top=None, title_size=56):
        """Eyebrow, title, body and a row of key caps / gesture chips, vertically centred."""
        tl = self.lines(title, title_size, "SemiBold", width)
        bl = self.lines(body, 28, "Regular", width)
        th, bh = title_size * 1.18, 28 * 1.55
        rows = self.how_rows(how, width)
        total = 42 + len(tl) * th + 22 + len(bl) * bh + (30 + len(rows) * 70 if rows else 0)
        y = top if top is not None else (self.h - total) / 2
        if eyebrow:
            self.d.ellipse(self.p(x, y + 3, x + 14, y + 17), fill=color)
            self.spaced(x + 26, y, eyebrow.upper(), 19, "SemiBold", color, 2.2)
        y += 42
        for line in tl:
            self.text(x, y, line, title_size, "SemiBold", INK)
            y += th
        y += 22
        for line in bl:
            self.text(x, y, line, 28, "Regular", BODY)
            y += bh
        y += 30
        for row in rows:
            cx = x
            for unit in row:
                cx = self.draw_unit(cx, y, unit, color) + 14
            y += 70

    # --- Key caps and gesture chips ---
    # A unit is a list of tokens kept on one line: ("key", "Ctrl"), ("+",), ("or",),
    # ("chip", "Drag & drop", "hand").

    def unit_width(self, unit):
        w = 0
        for t in unit:
            if t[0] == "key":
                w += max(54, self.width_of(t[1], 23, "Medium") + 36) + 8
            elif t[0] in ("+", "or", "–"):
                w += self.width_of(f" {t[0]} ", 23, "Medium") + 8
            else:
                w += self.width_of(t[1], 23, "Medium") + (40 + 30 if len(t) > 2 else 40) + 8
        return w - 8

    def how_rows(self, how, width):
        rows, row, used = [], [], 0
        for unit in how:
            w = self.unit_width(unit)
            if row and used + w > width:
                rows.append(row)
                row, used = [], 0
            row.append(unit)
            used += w + 14
        return rows + ([row] if row else [])

    def draw_unit(self, x, y, unit, color):
        for t in unit:
            if t[0] == "key":
                w = max(54, self.width_of(t[1], 23, "Medium") + 36)
                self.d.rounded_rectangle(self.p(x, y + 4, x + w, y + 54 + 4), 12 * SS, fill="#C7D0DB")
                self.d.rounded_rectangle(self.p(x, y, x + w, y + 54), 12 * SS, fill="#FFFFFF", outline="#D2D9E2",
                                         width=2 * SS)
                self.text(x + w / 2, y + 27, t[1], 23, "Medium", "#2A2F37", "mm")
                x += w + 8
            elif t[0] in ("+", "or", "–"):
                s = t[0]
                w = self.width_of(f" {s} ", 23, "Medium")
                self.text(x + w / 2, y + 29, s, 23, "Medium", MUTED, "mm")
                x += w + 8
            else:
                label, icon = t[1], (t[2] if len(t) > 2 else None)
                w = self.width_of(label, 23, "Medium") + (70 if icon else 40)
                self.d.rounded_rectangle(self.p(x, y, x + w, y + 54), 27 * SS, fill="#FFFFFF", outline="#D8DFE8",
                                         width=2 * SS)
                tx = x + 20
                if icon:
                    self.paste(ICONS.get(icon, 26 * SS, color), x + 18, y + 14)
                    tx += 30
                self.text(tx, y + 27, label, 23, "Medium", INK, "lm")
                x += w + 8
        return x - 8

    def chip(self, x, y, label, icon=None, color=ACCENT, size=24, h=56):
        w = self.width_of(label, size, "Medium") + (74 if icon else 44)
        self.shadow(x, y, w, h, h / 2, blur=10, alpha=0.06, dy=4)
        self.d.rounded_rectangle(self.p(x, y, x + w, y + h), h / 2 * SS, fill="#FFFFFF", outline="#DCE3EB",
                                 width=2 * SS)
        tx = x + 22
        if icon:
            self.paste(ICONS.get(icon, 26 * SS, color), x + 20, y + (h - 26) / 2)
            tx += 32
        self.text(tx, y + h / 2, label, size, "Medium", INK, "lm")
        return w

    # --- Annotations ---

    def cursor(self, x, y, k=2.3):
        pts = [(0, 0), (0, 22.5), (5.6, 17.3), (9.2, 25.5), (12.6, 24), (9.1, 16.1), (16.4, 16.1)]
        poly = [(x + px * k, y + py * k) for px, py in pts]
        m = Image.new("L", self.p(60, 80), 0)
        ImageDraw.Draw(m).polygon([(round(px * k * SS), round(py * k * SS)) for px, py in pts], fill=255)
        self.shadow(x, y, 0, 0, 0, blur=6, alpha=0.35, dy=3, mask=m)
        self.d.polygon([v for px, py in poly for v in self.p(px, py)], fill="#111111", outline="#FFFFFF",
                       width=round(2.4 * SS))

    def tooltip(self, x, y, s, anchor="l", color="#1E1E1E", size=22):
        """Dark label; (x, y) is the tip of its small pointer on side `anchor` (l/r/t/b)."""
        w, h = self.width_of(s, size, "Medium") + 36, size + 26
        if anchor == "l":
            bx, by = x + 9, y - h / 2
            tri = [(x, y), (bx + 1, y - 8), (bx + 1, y + 8)]
        elif anchor == "r":
            bx, by = x - 9 - w, y - h / 2
            tri = [(x, y), (bx + w - 1, y - 8), (bx + w - 1, y + 8)]
        elif anchor == "t":
            bx, by = x - w / 2, y + 9
            tri = [(x, y), (x - 8, by + 1), (x + 8, by + 1)]
        else:
            bx, by = x - w / 2, y - 9 - h
            tri = [(x, y), (x - 8, by + h - 1), (x + 8, by + h - 1)]
        self.shadow(bx, by, w, h, 10, blur=12, alpha=0.18, dy=6)
        self.d.rounded_rectangle(self.p(bx, by, bx + w, by + h), 10 * SS, fill=color)
        self.d.polygon([v for px, py in tri for v in self.p(px, py)], fill=color)
        self.text(bx + w / 2, by + h / 2, s, size, "Medium", "#FFFFFF", "mm")

    def ring(self, x, y, r, color=ACCENT):
        layer = Image.new("RGBA", self.img.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.ellipse(self.p(x - r, y - r, x + r, y + r), fill=rgba(color, 0.14), outline=rgba(color, 0.9),
                  width=round(3 * SS))
        self.img.alpha_composite(layer)

    def save(self, path, radius=28):
        out = self.img.resize((self.w, self.h), Image.LANCZOS)
        out = round_corners(out, radius)
        border = Image.new("RGBA", (self.w * 3, self.h * 3), (0, 0, 0, 0))
        ImageDraw.Draw(border).rounded_rectangle((0, 0, self.w * 3 - 1, self.h * 3 - 1), radius * 3,
                                                 outline=rgba("#D9E0E9"), width=5)
        out.alpha_composite(border.resize((self.w, self.h), Image.LANCZOS))
        out.save(path, optimize=True)
        print(f"    {os.path.basename(path)}  {self.w}x{self.h}")


# --- Banners ---

PAIR = (282, 128, 1134, 836)   # canvas close-up of two screens at 87%


def hero(inp, out):
    b = Banner(1800, 1000, glows=[(260, 80, 560, ACCENT, 0.16), (1580, 140, 480, PURPLE, 0.12),
                                  (900, 1000, 760, ACCENT, 0.12)])
    lockup = 96 + 26 + b.width_of("ui-flow", 88, "SemiBold")
    b.paste(ICONS.get("app", 96 * SS, None), 900 - lockup / 2, 64)
    b.text(900 - lockup / 2 + 122, 112, "ui-flow", 88, "SemiBold", INK, "lm")
    tag = "Map how the screens of your app connect, then press Play and click through them like a real user."
    y = 196
    for line in b.lines(tag, 33, "Regular", 1000):
        b.text(900, y, line, 33, "Regular", BODY, "mt")
        y += 50
    chips = [("Native & offline", "check"), ("One plain JSON file", "check"), ("Linux · Windows · Web", "check")]
    widths = [b.width_of(c[0], 24, "Medium") + 74 for c in chips]
    x = 900 - (sum(widths) + 16 * (len(chips) - 1)) / 2
    for (label, icon), w in zip(chips, widths):
        b.chip(x, 318, label, icon)
        x += w + 16
    win = b.shot(inp, "canvas", (0, 0, 1440, 900), 170, 430, 1460, radius=22, shadow=0.22)
    x, y = win(1392, 42)
    b.tooltip(x, y, "Press Play to click through", anchor="t")
    b.save(out)


def step_screens(inp, out):
    b = Banner(1800, 920, glows=[(1350, 460, 520, ACCENT, 0.12)])
    b.text_block(104, 560, "Step 1 · Screens", "Drop in your screenshots",
                 "Drag images onto the canvas, paste one from the clipboard or pick files. Each image becomes "
                 "a screen; the first one is where the flow starts.",
                 [[("chip", "Drag & drop", "image")], [("key", "Ctrl"), ("+",), ("key", "V")],
                  [("chip", "Add images…", "plus")]])
    b.shot(inp, "start", PAIR, 740, 110, 840)
    phones = os.path.join(inp, "example-app")
    for name, angle, x, y in (("3-caffe-latte.png", 7, 1500, 300), ("4-your-order.png", -5, 1580, 360)):
        im = Image.open(os.path.join(phones, name)).convert("RGBA")
        w = 200 * SS
        im = round_corners(im.resize((w, round(im.height * w / im.width)), Image.LANCZOS), 14 * SS)
        im = im.rotate(angle, resample=Image.BICUBIC, expand=True)
        b.shadow(x, y, 0, 0, 0, blur=24, alpha=0.22, dy=16, mask=im.getchannel("A"))
        b.paste(im, x, y)
    b.cursor(1640, 650)
    b.d.ellipse(b.p(1672, 700, 1716, 744), fill=ACCENT, outline="#FFFFFF", width=3 * SS)
    b.text(1694, 722, "+2", 20, "SemiBold", "#FFFFFF", "mm")
    b.tooltip(1630, 668, "Drop to add 2 screens", anchor="r")
    b.save(out)


def step_hotspots(inp, out):
    b = Banner(1800, 920, glows=[(540, 460, 520, ACCENT, 0.12)])
    b.text_block(1136, 560, "Step 2 · Hotspots", "Mark what can be clicked",
                 "Double-click a screen and drag rectangles over its buttons, links and fields. "
                 "Name them, nudge them with the arrow keys.",
                 [[("chip", "Double-click a screen", "hand")], [("chip", "Drag on the image", "hotspot")],
                  [("key", "Del")], [("key", "Esc")]])
    ed = b.shot(inp, "editor-drawing", (506, 70, 910, 880), 430, 64, 480)
    b.shot(inp, "editor-drawing", (0, 48, 248, 236), 120, 318, 360)
    cx, cy = ed(859, 550)
    b.cursor(cx - 3, cy - 3)
    b.tooltip(cx + 6, cy + 74, "Drag to draw a hotspot", anchor="t")
    b.save(out)


def step_links(inp, out):
    b = Banner(1800, 920, glows=[(1300, 460, 560, ACCENT, 0.12)])
    b.text_block(104, 560, "Step 3 · Links", "Connect hotspots to screens",
                 "Drag a hotspot onto the screen it opens and a blue arrow appears. In the editor, click the "
                 "circle next to a hotspot to pick the screen from a list.",
                 [[("chip", "Drag onto a screen", "link")], [("or",), ("chip", "Pick from a list", "chevron-down")]])
    c = b.shot(inp, "canvas-linking", PAIR, 760, 62, 960)
    cx, cy = c(951, 486)
    b.cursor(cx - 3, cy - 3)
    b.tooltip(cx + 20, cy + 76, "Drop it on the screen it opens", anchor="t")
    b.shot(inp, "editor-picker", (546, 361, 958, 641), 700, 576, 440, shadow=0.22)
    b.save(out)


def step_transitions(inp, out):
    b = Banner(1800, 920, glows=[(560, 460, 560, PURPLE, 0.12)])
    b.text_block(1136, 560, "Step 4 · Transitions", "Describe everything else",
                 "Not everything is a click. Drag a screen's purple handle onto another screen and write "
                 "what happens: a gesture, a timer, a scanned code.",
                 [[("chip", "Drag the purple handle", "arrow-right")], [("chip", "Say what happens", "edit")]],
                 color=PURPLE)
    c = b.shot(inp, "transition-new", PAIR, 80, 62, 960)
    hx, hy = c(609, 486)
    b.ring(hx, hy, 24, PURPLE)
    b.tooltip(hx - 4, hy - 34, "Purple handle", anchor="b", color=PURPLE)
    b.shot(inp, "transition-dialog", (521, 349, 919, 551), 560, 600, 520, radius=16, shadow=0.24)
    b.save(out)


def step_play(inp, out):
    b = Banner(1800, 920, glows=[(1300, 460, 560, ACCENT, 0.10)])
    b.text_block(104, 560, "Step 5 · Play", "Press Play and click through",
                 "The player opens at the start screen. Click hotspots, take described transitions with the "
                 "number keys and follow the path you took.",
                 [[("key", "F5")], [("key", "1"), ("–",), ("key", "9")], [("key", "Backspace")], [("key", "R")],
                  [("key", "H")]])
    phone = b.shot(inp, "player", (368, 60, 792, 896), 790, 26, 440, radius=20, border="#3A3A3A", shadow=0.28)
    panel = b.shot(inp, "player", (1161, 46, 1440, 410), 1300, 150, 440, radius=16, border="#3A3A3A", shadow=0.28)
    x, y = panel(1176, 114)
    b.tooltip(x - 8, y, "Press 1 to take it", anchor="r", color=PURPLE)
    x, y = phone(664, 858)
    b.tooltip(x + 4, y, "Messages show up as you go", anchor="l")
    b.save(out)


def md_lines(path, headings, width_chars, skip=()):
    """The given sections of a Markdown file, soft-wrapped, without lines starting with `skip`."""
    text = open(path, encoding="utf-8").read().splitlines()
    picked = []
    for heading in headings:
        i = text.index(heading)
        level = len(heading) - len(heading.lstrip("#"))
        j = next((n for n in range(i + 1, len(text))
                  if text[n].startswith("#") and len(text[n]) - len(text[n].lstrip("#")) <= level), len(text))
        picked += text[i:j] + [""]
    out = []
    for line in picked:
        if line.startswith(skip) or (not line and out and not out[-1]):
            continue
        while len(line) > width_chars:  # soft wrap with a hanging indent
            cut = line.rfind(" ", 0, width_chars)
            cut = cut if cut > 20 else width_chars
            out.append(line[:cut])
            line = "  " + line[cut:].lstrip()
        out.append(line)
    return out


def code_card(b, x, y, w, h, title, lines, color_line, size=19.5):
    b.shadow(x, y, w, h, 18, alpha=0.16)
    b.d.rounded_rectangle(b.p(x, y, x + w, y + h), 18 * SS, fill="#FFFFFF")
    b.d.rounded_rectangle(b.p(x, y, x + w, y + 56), 18 * SS, fill="#F6F8FB")
    b.d.rectangle(b.p(x, y + 38, x + w, y + 56), fill="#F6F8FB")
    b.d.line(b.p(x, y + 56, x + w, y + 56), fill=LINE, width=SS)
    for i, c in enumerate(("#FF5F57", "#FEBC2E", "#28C840")):
        b.d.ellipse(b.p(x + 22 + i * 20, y + 22, x + 34 + i * 20, y + 34), fill=c)
    b.paste(ICONS.get("file", 22 * SS, MUTED), x + 100, y + 17)
    b.text(x + 130, y + 28, title, 20, "Medium", BODY, "lm")
    ly = y + 80
    for line in lines:
        if ly > y + h - 30:
            break
        lx = x + 30
        for s, color, weight in color_line(line):
            b.text(lx, ly, s, size, weight, color)
            lx += b.width_of(s, size, weight)
        ly += size * 1.62
    b.outline(x, y, w, h, 18, LINE)


def color_markdown(line):
    if line.startswith("#"):
        return [(line, INK, "MonoBold")]
    if line.startswith(">"):
        return [(line, PURPLE, "Mono")]
    if line.startswith("|"):
        parts = re.split(r"(\|)", line)
        return [(p, MUTED if p == "|" or set(p) <= set("-|") else INK, "Mono") for p in parts if p]
    if line.startswith("- Hotspot"):
        return [("- ", MUTED, "Mono"), (line[2:], WARN, "Mono")]
    m = re.match(r"(How to reach:|Reached from:)(.*)", line)
    if m:
        return [(m.group(1), ACCENT, "Mono"), (m.group(2), BODY, "Mono")]
    return [(line, BODY, "Mono")]


def color_json(line):
    out = []
    for tok in re.findall(r'"(?:[^"\\]|\\.)*"\s*:|"(?:[^"\\]|\\.)*"|-?\d+\.?\d*|[{}\[\],:]|\s+|[^\s]+', line):
        if tok.endswith(":") and tok.startswith('"'):
            out += [(tok[:-1].rstrip(), "#0B6BCB", "Mono"), (":", MUTED, "Mono")]
        elif tok.startswith('"'):
            out.append((tok, "#1A7F37", "Mono"))
        elif re.fullmatch(r"-?\d+\.?\d*", tok):
            out.append((tok, "#C2410C", "Mono"))
        elif tok.strip() in "{}[],":
            out.append((tok, MUTED, "Mono"))
        else:
            out.append((tok, BODY, "Mono"))
    return out


def overview(inp, out):
    b = Banner(1800, 920, glows=[(1300, 420, 560, GREEN, 0.08), (1600, 800, 400, ACCENT, 0.08)])
    b.text_block(104, 560, "Flow check", "See the whole flow at a glance",
                 "Every screen lists how it is reached from the start. Unreachable screens and hotspots that "
                 "lead nowhere are flagged, and the whole flow exports to Markdown.",
                 [[("chip", "Export flow as Markdown…", "export")]], color=GREEN)
    # The Screens panel and its Flow check, stacked into one card.
    shot = Image.open(os.path.join(inp, "canvas.png")).convert("RGBA")
    top = shot.crop((0, 50 * S, 248 * S, 400 * S))
    bottom = shot.crop((0, 802 * S, 248 * S, 894 * S))
    panel = Image.new("RGBA", (top.width, top.height + bottom.height + 2 * S), "#FFFFFF")
    panel.paste(top, (0, 0))
    ImageDraw.Draw(panel).line((0, top.height + S, panel.width, top.height + S), fill="#E6E6E6", width=S)
    panel.paste(bottom, (0, top.height + 2 * S))
    b.card(panel, 740, 76, 440)
    lines = md_lines(os.path.join(inp, "example.md"), ["### Order placed", "## Warnings"], 50,
                     skip=("Reached from:",))
    code_card(b, 1130, 150, 760, 820, "Kettle.md", lines, color_markdown)
    b.save(out)


def fact(title, body, color=ACCENT, glow=None):
    b = Banner(880, 600, glows=[glow or (700, 520, 380, color, 0.12)])
    y = 52
    for line in b.lines(title, 40, "SemiBold", 760):
        b.text(56, y, line, 40, "SemiBold", INK)
        y += 50
    y += 10
    for line in b.lines(body, 24, "Regular", 760):
        b.text(56, y, line, 24, "Regular", BODY)
        y += 37
    return b


def fact_json(inp, out):
    b = fact("One plain JSON file", "Screens, hotspots, links and the images themselves, pretty-printed. "
             "Diff it, commit it, read it.")
    ex = json.load(open(os.path.join(inp, "example-excerpt.json"), encoding="utf-8"))
    s, img = ex["screens"][0], ex["images"][0]
    h, (l1, l2) = s["hotspots"][0], ex["links"]
    q = lambda v: json.dumps(v, ensure_ascii=False)
    keep = ["{",
            f'  "format": {q(ex["format"])}, "version": {ex["version"]}, "name": {q(ex["name"])},',
            f'  "screens": [ {{ "id": {q(s["id"])}, "name": {q(s["name"])},',
            f'      "hotspots": [ {{ "name": {q(h["name"])}, "x": {h["x"]}, "y": {h["y"]}, ... }} ] }} ],',
            f'  "links": [ {{ "from": {q(l1["from"])}, "hotspot": {q(l1["hotspot"])}, "to": {q(l1["to"])} }},',
            f'      {{ "from": {q(l2["from"])}, "to": {q(l2["to"])}, "message": {q(l2["message"])} }} ],',
            f'  "images": [ {{ "file": {q(img["file"])}, "data": {q(img["data"][:16] + "...")} }} ]',
            "}"]
    code_card(b, 56, 228, 900, 420, "Kettle.json", keep, color_json, size=16.5)
    b.save(out)


def fact_platforms(inp, out):
    b = fact("Native, offline, everywhere", "C++17 and Qt 6. No account, no server. Linux and Windows on "
             "x64 and arm64, plus a web build.", glow=(440, 560, 420, ACCENT, 0.12))
    tiles = [("Linux", "x64 · arm64", "desktop"), ("Windows", "x64 · arm64", "desktop"), ("Web", "WebAssembly", "web")]
    for i, (name, sub, kind) in enumerate(tiles):
        x, y, w, h = 56 + i * 262, 250, 240, 290
        b.shadow(x, y, w, h, 20, blur=20, alpha=0.10, dy=10)
        b.d.rounded_rectangle(b.p(x, y, x + w, y + h), 20 * SS, fill="#FFFFFF")
        b.outline(x, y, w, h, 20, LINE)
        cx, cy = x + w / 2, y + 100
        b.d.ellipse(b.p(cx - 52, cy - 52, cx + 52, cy + 52), fill=ACCENT_SOFT)
        if kind == "desktop":
            b.d.rounded_rectangle(b.p(cx - 30, cy - 22, cx + 30, cy + 16), 5 * SS, outline=ACCENT, width=4 * SS)
            b.d.line(b.p(cx, cy + 16, cx, cy + 26), fill=ACCENT, width=4 * SS)
            b.d.line(b.p(cx - 14, cy + 27, cx + 14, cy + 27), fill=ACCENT, width=4 * SS)
        else:
            b.d.ellipse(b.p(cx - 28, cy - 28, cx + 28, cy + 28), outline=ACCENT, width=4 * SS)
            b.d.ellipse(b.p(cx - 12, cy - 28, cx + 12, cy + 28), outline=ACCENT, width=3 * SS)
            b.d.line(b.p(cx - 27, cy, cx + 27, cy), fill=ACCENT, width=3 * SS)
        b.text(cx, y + 196, name, 30, "SemiBold", INK, "mm")
        b.text(cx, y + 236, sub, 21, "Medium", MUTED, "mm")
    b.save(out)


def fact_keyboard(inp, out):
    b = fact("Keyboard-first", "Every action has a shortcut. Press F1 to see them all.",
             glow=(620, 600, 420, ACCENT, 0.12))
    b.shot(inp, "shortcuts", (441, 87, 999, 560), 150, 196, 600, radius=14, shadow=0.20)
    b.save(out)


def fact_autosave(inp, out):
    b = fact("Autosave, undo, redo", "Changes are saved a second after you stop editing. Undo and redo "
             "cover every change.", glow=(560, 600, 420, ACCENT, 0.12))
    b.shot(inp, "app-menu", (0, 0, 560, 452), 150, 214, 600, radius=14, shadow=0.20)
    b.save(out)


BANNERS = [("hero", hero), ("1-screens", step_screens), ("2-hotspots", step_hotspots), ("3-links", step_links),
           ("4-transitions", step_transitions), ("5-play", step_play), ("flow-check", overview),
           ("json-file", fact_json), ("platforms", fact_platforms), ("keyboard", fact_keyboard),
           ("autosave", fact_autosave)]


def main():
    args = sys.argv[1:]
    icons = "src/app/icons"
    if "--icons" in args:
        i = args.index("--icons")
        icons = args[i + 1]
        del args[i:i + 2]
    only = None
    if "--only" in args:
        i = args.index("--only")
        only = set(args[i + 1].split(","))
        del args[i:i + 2]
    if len(args) != 2:
        sys.exit(__doc__)
    inputs, out_dir = args
    global ICONS
    ICONS = Icons(icons)
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in BANNERS:
        if only is None or name in only:
            fn(inputs, os.path.join(out_dir, name + ".png"))


if __name__ == "__main__":
    main()
