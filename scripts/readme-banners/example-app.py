#!/usr/bin/env python3
"""example-app.py <out.json> [<png-dir>] - writes the sample app shown in the README
banners: "Kettle", a made-up coffee ordering app. Six drawn phone screens (390 x 844 pt
@2x) with hotspots, links between them and two described transitions; two hotspots are
left unlinked on purpose so the flow check has something to say. With <png-dir>, the
screens are also written there as PNG files (the "screenshots" a user would drop in).

example-app.py --subset <in.json> <out.json> <screen-id,...> [<link-id,...>] - copies an
app with only some of its screens (and without the given links), for close-up shots."""
import base64
import io
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

INTER = os.environ.get("UIFLOW_INTER_DIR", "/opt/deps/inter")
W, H = 390, 844       # points
PT = 4                # drawing pixels per point; the PNG is downsampled to 2 px per point
OUT_SCALE = 2

CREAM, WHITE, INK, MUTED, LINE = "#FBF7F2", "#FFFFFF", "#1D1B19", "#857C73", "#ECE4DA"
BRAND, BRAND_SOFT, BRAND_LIGHT = "#1F5F4A", "#E3EFE9", "#2B7059"
SAND, LATTE, COFFEE, DARK_COFFEE, FOAM = "#F3E4D0", "#C69467", "#8A5A36", "#4A3020", "#F8ECDD"
RED = "#D64545"

_fonts = {}


def font(size, weight="Regular"):
    key = (size, weight)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(os.path.join(INTER, f"Inter-{weight}.ttf"), round(size * PT))
    return _fonts[key]


class Phone:
    """One phone screen, drawn in points at PT pixels per point."""

    def __init__(self, sid, name, bg=CREAM):
        self.id, self.name = sid, name
        self.img = Image.new("RGB", (W * PT, H * PT), bg)
        self.d = ImageDraw.Draw(self.img)
        self.hotspots = []

    @staticmethod
    def p(*v):
        return [round(x * PT) for x in v]

    def rect(self, x, y, w, h, r=0, fill=None, outline=None, width=1):
        self.d.rounded_rectangle(self.p(x, y, x + w, y + h), radius=round(r * PT), fill=fill,
                                 outline=outline, width=round(width * PT))

    def circle(self, cx, cy, r, fill=None, outline=None, width=1):
        self.d.ellipse(self.p(cx - r, cy - r, cx + r, cy + r), fill=fill, outline=outline, width=round(width * PT))

    def line(self, pts, fill=INK, width=2, joint="curve"):
        self.d.line([round(v * PT) for xy in pts for v in xy], fill=fill, width=round(width * PT), joint=joint)
        for x, y in (pts[0], pts[-1]):  # round caps
            self.circle(x, y, width / 2, fill=fill)

    def text(self, x, y, s, size, color=INK, weight="Regular", anchor="la"):
        self.d.text(self.p(x, y), s, font=font(size, weight), fill=color, anchor=anchor)

    def text_width(self, s, size, weight="Regular"):
        return self.d.textlength(s, font=font(size, weight)) / PT

    def wrap(self, x, y, s, size, width, color=MUTED, weight="Regular", leading=1.45, center=False):
        words, line = s.split(), ""
        for word in words + [None]:
            candidate = (line + " " + word).strip() if word else line
            if word is None or (line and self.text_width(candidate, size, weight) > width):
                tx = x + (width - self.text_width(line, size, weight)) / 2 if center else x
                self.text(tx, y, line, size, color, weight)
                y += size * leading
                line = word or ""
            else:
                line = candidate

    def hot(self, hid, name, x, y, w, h):
        self.hotspots.append({"id": hid, "name": name, "x": x * OUT_SCALE, "y": y * OUT_SCALE,
                              "w": w * OUT_SCALE, "h": h * OUT_SCALE})

    # --- Building blocks ---

    def status_bar(self, color=INK):
        self.text(32, 22, "9:41", 15, color, "SemiBold")
        for i in range(4):  # signal
            self.rect(300 + i * 5, 32 - i * 2.5, 3, 5 + i * 2.5, 1, fill=color)
        self.rect(328, 24, 24, 12, 3.5, outline=color, width=1)
        self.rect(330.5, 26.5, 16, 7, 2, fill=color)
        self.rect(353, 28, 2, 4, 1, fill=color)

    def home_indicator(self, color=INK):
        self.rect(128, 830, 134, 5, 2.5, fill=color)

    def button(self, x, y, w, h, label, primary=True):
        if primary:
            self.rect(x, y, w, h, h / 2, fill=BRAND)
        else:
            self.rect(x, y, w, h, h / 2, fill=WHITE, outline=LINE, width=1.5)
        self.text(x + w / 2, y + h / 2, label, 17, WHITE if primary else INK, "SemiBold", "mm")

    def back_button(self, x=44, y=70, bg=WHITE):
        self.circle(x, y, 20, fill=bg)
        self.line([(x + 3, y - 7), (x - 4, y), (x + 3, y + 7)], INK, 2.2, joint=None)

    def chevron_right(self, x, y, color=MUTED):
        self.line([(x - 3, y - 6), (x + 3, y), (x - 3, y + 6)], color, 2, joint=None)

    def tab_bar(self, active):
        self.rect(0, 764, W, 80, fill=WHITE)
        self.d.line(self.p(0, 764, W, 764), fill=LINE, width=PT)
        for i, (label, icon) in enumerate([("Menu", self.icon_home), ("Orders", self.icon_receipt),
                                           ("Profile", self.icon_person)]):
            cx = 65 + i * 130
            color = BRAND if label == active else "#A39A90"
            icon(cx, 790, color)
            self.text(cx, 816, label, 11, color, "SemiBold" if label == active else "Medium", "mm")
        self.home_indicator()

    # --- Icons (24 pt box centred on cx, cy) ---

    def icon_home(self, cx, cy, color):
        self.line([(cx - 9, cy - 1), (cx, cy - 9), (cx + 9, cy - 1)], color, 2)
        self.line([(cx - 6.5, cy - 2), (cx - 6.5, cy + 8), (cx + 6.5, cy + 8), (cx + 6.5, cy - 2)], color, 2)

    def icon_receipt(self, cx, cy, color):
        self.rect(cx - 7, cy - 9, 14, 18, 2.5, outline=color, width=2)
        for dy in (-3, 2):
            self.line([(cx - 3, cy + dy), (cx + 3, cy + dy)], color, 1.8)

    def icon_person(self, cx, cy, color):
        self.circle(cx, cy - 4, 4.5, outline=color, width=2)
        self.d.arc(self.p(cx - 8, cy + 2, cx + 8, cy + 18), 180, 360, fill=color, width=2 * PT)

    def icon_bag(self, cx, cy, color):
        self.rect(cx - 8, cy - 4, 16, 14, 3, outline=color, width=2)
        self.d.arc(self.p(cx - 4.5, cy - 10, cx + 4.5, cy + 1), 180, 360, fill=color, width=2 * PT)

    def icon_search(self, cx, cy, color):
        self.circle(cx - 1.5, cy - 1.5, 6, outline=color, width=2)
        self.line([(cx + 3, cy + 3), (cx + 7, cy + 7)], color, 2)

    def icon_pin(self, cx, cy, color):
        self.d.polygon(self.p(cx - 5.8, cy - 2, cx + 5.8, cy - 2, cx, cy + 9), fill=color)
        self.circle(cx, cy - 3, 6.5, fill=color)
        self.circle(cx, cy - 3, 2.5, fill=WHITE)

    def icon_card(self, cx, cy, color):
        self.rect(cx - 10, cy - 7, 20, 14, 3, outline=color, width=2)
        self.line([(cx - 9, cy - 2), (cx + 9, cy - 2)], color, 2)

    def heart(self, cx, cy, s, color):
        r = s * 0.29
        self.circle(cx - r * 0.95, cy - r * 0.55, r, fill=color)
        self.circle(cx + r * 0.95, cy - r * 0.55, r, fill=color)
        self.d.polygon(self.p(cx - r * 1.9, cy - r * 0.3, cx + r * 1.9, cy - r * 0.3, cx, cy + s * 0.55), fill=color)

    # --- Illustrations (top-down cups, pastry, beans) ---

    def cup(self, cx, cy, r, kind="latte"):
        self.circle(cx + r * 0.05, cy + r * 0.09, r, fill="#E9DCCB")  # saucer shadow
        self.circle(cx, cy, r, fill=WHITE)
        self.circle(cx, cy, r * 0.93, outline="#F1E8DD", width=r * 0.02)
        self.rect(cx + r * 0.55, cy - r * 0.13, r * 0.42, r * 0.26, r * 0.13, fill=WHITE, outline="#EADFD2",
                  width=r * 0.025)
        self.circle(cx, cy, r * 0.68, fill="#F6EFE6")
        if kind == "cold":
            self.circle(cx, cy, r * 0.6, fill=DARK_COFFEE)
            for ang, d in ((-40, 0.28), (75, 0.3), (200, 0.24)):
                x = cx + math.cos(math.radians(ang)) * r * d
                y = cy + math.sin(math.radians(ang)) * r * d
                self.rect(x - r * 0.13, y - r * 0.13, r * 0.26, r * 0.26, r * 0.06, fill="#E4EEF0")
            self.circle(cx + r * 0.22, cy - r * 0.2, r * 0.06, fill=WHITE)
            return
        self.circle(cx, cy, r * 0.6, fill=COFFEE)
        self.circle(cx, cy, r * 0.54, fill=LATTE)
        if kind == "latte":
            self.heart(cx, cy - r * 0.06, r * 0.5, FOAM)
            self.circle(cx, cy - r * 0.06, r * 0.07, fill=LATTE)
        elif kind == "cappuccino":
            self.circle(cx, cy, r * 0.44, fill=FOAM)
            for ang in range(0, 360, 40):
                x = cx + math.cos(math.radians(ang)) * r * 0.18
                y = cy + math.sin(math.radians(ang)) * r * 0.18
                self.circle(x, y, r * 0.03, fill="#B98A62")
        else:  # flat white
            self.circle(cx, cy, r * 0.32, fill=FOAM)
            self.circle(cx, cy, r * 0.2, fill=LATTE)
            self.circle(cx, cy, r * 0.11, fill=FOAM)

    def bun(self, cx, cy, r):
        self.circle(cx + r * 0.04, cy + r * 0.08, r, fill="#E2CDB1")
        self.circle(cx, cy, r, fill="#D9A066")
        for i in range(4):
            rr = r * (0.22 + i * 0.19)
            self.d.arc(self.p(cx - rr, cy - rr, cx + rr, cy + rr), i * 80, i * 80 + 250, fill="#B0743F",
                       width=round(r * 0.07 * PT))
        self.d.line(self.p(cx - r * 0.5, cy - r * 0.2, cx + r * 0.5, cy + r * 0.2), fill="#F7E7D0",
                    width=round(r * 0.08 * PT))

    def bean(self, cx, cy, size, angle, color="#3E7A65"):
        s = round(size * PT)
        tile = Image.new("RGBA", (s * 2, s * 2), (0, 0, 0, 0))
        td = ImageDraw.Draw(tile)
        td.ellipse((s // 2, s // 4 * 3 - s // 8, s * 3 // 2, s * 5 // 4 + s // 8), fill=color)
        td.arc((s // 2 + s // 6, s // 4 * 3, s * 3 // 2 - s // 6, s * 5 // 4), 200, 340, fill=BRAND, width=max(2, s // 12))
        tile = tile.rotate(angle, resample=Image.BICUBIC)
        self.img.paste(tile, (round(cx * PT) - s, round(cy * PT) - s), tile)

    def png(self):
        small = self.img.resize((W * OUT_SCALE, H * OUT_SCALE), Image.LANCZOS)
        buf = io.BytesIO()
        small.save(buf, "PNG", optimize=True)
        return buf.getvalue()


def welcome():
    s = Phone("screen-1", "Welcome")
    s.rect(0, -40, W, 520, 40, fill=BRAND)
    s.status_bar(WHITE)
    for r, c in ((172, "#24664F"), (132, "#296C55")):
        s.circle(195, 285, r, fill=c)
    for x, y, a in ((58, 150, 30), (340, 190, -20), (70, 420, 70), (330, 410, 10), (300, 120, 60)):
        s.bean(x, y, 14, a)
    s.text(195, 78, "kettle", 20, WHITE, "SemiBold", "mm")
    s.cup(195, 285, 118, "latte")
    s.text(32, 532, "Coffee, your way", 32, INK, "SemiBold")
    s.wrap(32, 582, "Order ahead from your favourite café and skip the line, every morning.", 17, 320)
    s.rect(32, 664, 22, 6, 3, fill=BRAND)
    s.circle(65, 667, 3, fill="#D9D0C5")
    s.circle(77, 667, 3, fill="#D9D0C5")
    s.button(24, 700, 342, 56, "Get started")
    s.text(195, 790, "I already have an account", 16, BRAND, "SemiBold", "mm")
    s.home_indicator()
    s.hot("hotspot-1", "Get started", 24, 700, 342, 56)
    s.hot("hotspot-2", "Sign in", 90, 772, 210, 36)
    return s


PRODUCTS = [("Caffè latte", "Espresso, steamed milk", "$4.50", "latte", SAND),
            ("Cappuccino", "Extra foam, cocoa", "$4.20", "cappuccino", "#EFE5D8"),
            ("Flat white", "Velvety microfoam", "$4.30", "flat", "#F2E8DC"),
            ("Cold brew", "Steeped for 18 hours", "$4.80", "cold", "#E3ECE7")]


def menu():
    s = Phone("screen-2", "Menu")
    s.status_bar()
    s.text(24, 66, "Good morning, Alex", 15, MUTED, "Medium")
    s.text(24, 88, "What are you having?", 25, INK, "SemiBold")
    s.circle(344, 84, 22, fill=WHITE, outline=LINE, width=1)
    s.icon_bag(344, 85, INK)
    s.circle(360, 66, 9, fill=BRAND)
    s.text(360, 66, "2", 11, WHITE, "SemiBold", "mm")
    s.rect(24, 136, 342, 48, 14, fill=WHITE, outline=LINE, width=1)
    s.icon_search(48, 160, MUTED)
    s.text(66, 160, "Search drinks and food", 15, "#A39A90", anchor="lm")
    x = 24
    for i, chip in enumerate(["Coffee", "Tea", "Bakery", "Cold drinks"]):
        w = s.text_width(chip, 14, "SemiBold") + 32
        if i == 0:
            s.rect(x, 202, w, 36, 18, fill=BRAND)
        else:
            s.rect(x, 202, w, 36, 18, fill=WHITE, outline=LINE, width=1)
        s.text(x + w / 2, 220, chip, 14, WHITE if i == 0 else INK, "SemiBold", "mm")
        x += w + 8
    s.text(24, 262, "Popular", 18, INK, "SemiBold")
    s.text(366, 266, "See all", 14, BRAND, "SemiBold", "ra")
    for i, (name, sub, price, kind, tint) in enumerate(PRODUCTS):
        x, y = 24 + (i % 2) * 178, 296 + (i // 2) * 226
        s.rect(x, y, 164, 212, 20, fill=WHITE, outline=LINE, width=1)
        s.rect(x + 8, y + 8, 148, 116, 14, fill=tint)
        s.cup(x + 82, y + 66, 44, kind)
        s.text(x + 14, y + 136, name, 16, INK, "SemiBold")
        s.text(x + 14, y + 158, sub, 12.5, MUTED)
        s.text(x + 14, y + 184, price, 15, INK, "SemiBold")
        s.circle(x + 140, y + 190, 14, fill=BRAND)
        s.line([(x + 140, y + 184), (x + 140, y + 196)], WHITE, 2)
        s.line([(x + 134, y + 190), (x + 146, y + 190)], WHITE, 2)
    s.tab_bar("Menu")
    s.hot("hotspot-3", "Caffè latte", 24, 296, 164, 212)
    s.hot("hotspot-4", "Cart", 322, 62, 44, 44)
    s.hot("hotspot-5", "Profile tab", 280, 770, 90, 60)
    return s


def product():
    s = Phone("screen-3", "Caffè latte")
    s.rect(0, -40, W, 420, 40, fill=SAND)
    s.status_bar()
    s.back_button()
    s.circle(346, 70, 20, fill=WHITE)
    s.heart(346, 70, 16, "#E26B5D")
    s.cup(195, 222, 122, "latte")
    s.text(24, 404, "Caffè latte", 28, INK, "SemiBold")
    s.text(366, 410, "$4.50", 22, BRAND, "SemiBold", "ra")
    s.wrap(24, 450, "Double espresso with steamed milk and a thin layer of foam.", 15.5, 330)
    s.text(24, 516, "Size", 16, INK, "SemiBold")
    s.rect(24, 544, 342, 48, 14, fill="#F1EADF")
    for i, size in enumerate(["Small", "Medium", "Large"]):
        x = 24 + i * 114
        if i == 1:
            s.rect(x + 4, 548, 106, 40, 11, fill=WHITE)
        s.text(x + 57, 568, size, 14.5, INK if i == 1 else MUTED, "SemiBold" if i == 1 else "Medium", "mm")
    s.text(24, 614, "Milk", 16, INK, "SemiBold")
    x = 24
    for i, milk in enumerate(["Whole", "Oat", "Almond", "None"]):
        w = s.text_width(milk, 14, "SemiBold") + 34
        if i == 0:
            s.rect(x, 642, w, 40, 20, fill=BRAND_SOFT, outline=BRAND, width=1.5)
        else:
            s.rect(x, 642, w, 40, 20, fill=WHITE, outline=LINE, width=1)
        s.text(x + w / 2, 662, milk, 14, BRAND if i == 0 else INK, "SemiBold", "mm")
        x += w + 8
    s.text(24, 712, "Extra shot", 16, INK, "Medium")
    s.text(114, 714, "+$0.80", 14, MUTED)
    s.rect(318, 706, 48, 28, 14, fill="#E2DAD0")
    s.circle(332, 720, 11, fill=WHITE)
    s.button(24, 756, 342, 56, "Add to order  ·  $4.50")
    s.home_indicator()
    s.hot("hotspot-6", "Back", 24, 50, 40, 40)
    s.hot("hotspot-7", "Add to order", 24, 756, 342, 56)
    return s


def cart():
    s = Phone("screen-4", "Your order")
    s.status_bar()
    s.back_button(bg="#F1EADF")
    s.text(195, 70, "Your order", 18, INK, "SemiBold", "mm")
    items = [("Caffè latte", "Medium · Whole milk", "$4.50", "cup"), ("Cinnamon roll", "Warmed", "$3.20", "bun")]
    for i, (name, sub, price, kind) in enumerate(items):
        y = 116 + i * 92
        s.rect(24, y, 68, 68, 16, fill=SAND if kind == "cup" else "#F4E7D7")
        if kind == "cup":
            s.cup(58, y + 34, 25, "latte")
        else:
            s.bun(58, y + 34, 22)
        s.text(106, y + 12, name, 16, INK, "SemiBold")
        s.text(106, y + 35, sub, 13, MUTED)
        s.text(106, y + 54, price, 14.5, INK, "SemiBold")
        s.rect(282, y + 20, 84, 32, 16, fill=WHITE, outline=LINE, width=1)
        s.text(298, y + 36, "–", 16, MUTED, "Medium", "mm")
        s.text(324, y + 36, "1", 14, INK, "SemiBold", "mm")
        s.text(350, y + 36, "+", 16, INK, "Medium", "mm")
        if i == 0:
            s.d.line(s.p(24, y + 82, 366, y + 82), fill=LINE, width=PT)
    for i, (title, sub, icon, action) in enumerate([
            ("Pick up at Main St.", "Ready in about 6 min · 250 m away", s.icon_pin, None),
            ("Card •••• 4242", "Visa debit", s.icon_card, "Change")]):
        y = 316 + i * 86
        s.rect(24, y, 342, 72, 16, fill=WHITE, outline=LINE, width=1)
        s.circle(58, y + 36, 19, fill=BRAND_SOFT)
        icon(58, y + 36, BRAND)
        s.text(90, y + 18, title, 15, INK, "SemiBold")
        s.text(90, y + 40, sub, 13, MUTED)
        if action:
            s.text(350, y + 36, action, 14, BRAND, "SemiBold", "rm")
        else:
            s.chevron_right(348, y + 36)
    for i, (label, value) in enumerate([("Subtotal", "$7.70"), ("Service fee", "$0.30")]):
        s.text(24, 516 + i * 30, label, 15, MUTED)
        s.text(366, 516 + i * 30, value, 15, INK, "Medium", "ra")
    s.d.line(s.p(24, 584, 366, 584), fill=LINE, width=PT)
    s.text(24, 600, "Total", 18, INK, "SemiBold")
    s.text(366, 600, "$8.00", 18, INK, "SemiBold", "ra")
    s.button(24, 756, 342, 56, "Place order  ·  $8.00")
    s.home_indicator()
    s.hot("hotspot-8", "Back", 24, 50, 40, 40)
    s.hot("hotspot-9", "Place order", 24, 756, 342, 56)
    return s


def confirmed():
    s = Phone("screen-5", "Order placed")
    s.status_bar()
    s.circle(195, 236, 96, fill=BRAND_SOFT)
    s.circle(195, 236, 64, fill=BRAND)
    s.line([(168, 238), (187, 257), (224, 218)], WHITE, 9)
    s.text(195, 380, "Order placed!", 30, INK, "SemiBold", "mm")
    s.wrap(40, 410, "We'll have it ready in about 6 minutes. We'll let you know.", 16, 310, center=True)
    s.rect(24, 488, 342, 168, 20, fill=WHITE, outline=LINE, width=1)
    s.text(44, 510, "Order #A-204", 16, INK, "SemiBold")
    s.text(44, 534, "Main St. · Pickup", 13, MUTED)
    s.rect(272, 508, 74, 26, 13, fill=BRAND_SOFT)
    s.text(309, 521, "6 min", 12.5, BRAND, "SemiBold", "mm")
    s.rect(66, 588, 129, 4, 2, fill=BRAND)
    s.rect(195, 588, 129, 4, 2, fill="#E7E0D6")
    for i, label in enumerate(["Received", "Preparing", "Ready"]):
        x = 66 + i * 129
        done = i < 2
        s.circle(x, 590, 11, fill=BRAND if done else WHITE, outline=None if done else "#D9D0C5", width=2)
        if done:
            s.line([(x - 4.5, 590), (x - 1, 594), (x + 5, 586)], WHITE, 2.2)
        s.text(x, 622, label, 12.5, INK if done else MUTED, "SemiBold" if done else "Medium", "mm")
    s.button(24, 700, 342, 56, "Track order")
    s.text(195, 790, "Back to the menu in a moment…", 14, MUTED, "Medium", "mm")
    s.home_indicator()
    s.hot("hotspot-10", "Track order", 24, 700, 342, 56)
    return s


def profile():
    s = Phone("screen-6", "Profile")
    s.status_bar()
    s.back_button(bg="#F1EADF")
    s.text(195, 70, "Profile", 18, INK, "SemiBold", "mm")
    s.circle(195, 168, 46, fill=BRAND_SOFT)
    s.text(195, 168, "AD", 28, BRAND, "SemiBold", "mm")
    s.text(195, 238, "Alex Doe", 21, INK, "SemiBold", "mm")
    s.text(195, 264, "alex@example.com", 14, MUTED, anchor="mm")
    s.rect(24, 296, 342, 124, 20, fill=BRAND)
    s.text(44, 316, "Rewards", 16, WHITE, "SemiBold")
    s.text(44, 340, "2 more orders for a free drink", 13, "#BFD8CE")
    for i in range(8):
        cx = 56 + i * 40
        if i < 6:
            s.circle(cx, 388, 14, fill=WHITE)
            s.circle(cx, 388, 6, fill=LATTE)
        else:
            s.circle(cx, 388, 14, fill=BRAND_LIGHT, outline="#5E9784", width=1.5)
    for i, label in enumerate(["Order history", "Payment methods", "Notifications", "Help & support"]):
        y = 444 + i * 56
        s.circle(44, y + 26, 18, fill="#F1EADF")
        [s.icon_receipt, s.icon_card, s.icon_bag, s.icon_search][i](44, y + 26, INK)
        s.text(76, y + 26, label, 16, INK, "Medium", "lm")
        s.chevron_right(358, y + 26)
        s.d.line(s.p(76, y + 54, 366, y + 54), fill=LINE, width=PT)
    s.text(24, 694, "Sign out", 16, RED, "SemiBold", "lm")
    s.tab_bar("Profile")
    s.hot("hotspot-11", "Back", 24, 50, 40, 40)
    s.hot("hotspot-12", "Sign out", 16, 674, 120, 40)
    return s


def main(out, png_dir=None):
    screens = [welcome(), menu(), product(), cart(), confirmed(), profile()]
    layout = {"screen-1": (0, 0), "screen-2": (560, 0), "screen-3": (1120, 0), "screen-4": (1680, 0),
              "screen-5": (1680, 960), "screen-6": (560, 960)}
    links = [  # (from, hotspot or "" for a described transition, to, message)
        ("screen-1", "hotspot-1", "screen-2", ""),
        ("screen-2", "hotspot-3", "screen-3", ""),
        ("screen-2", "hotspot-4", "screen-4", ""),
        ("screen-2", "hotspot-5", "screen-6", ""),
        ("screen-3", "hotspot-6", "screen-2", ""),
        ("screen-3", "hotspot-7", "screen-4", ""),
        ("screen-4", "hotspot-8", "screen-3", ""),
        ("screen-4", "hotspot-9", "screen-5", "payment is confirmed"),
        ("screen-5", "", "screen-2", "after 5 seconds"),
        ("screen-6", "hotspot-11", "screen-2", ""),
        ("screen-6", "hotspot-12", "screen-1", ""),
    ]
    scale = round(720 / (H * OUT_SCALE), 4)
    images = []
    for i, s in enumerate(screens):
        data = s.png()
        file = s.name.lower().replace(" ", "-").replace("è", "e") + ".png"
        images.append({"id": f"img-{i + 1}", "file": file, "mime": "image/png", "width": W * OUT_SCALE,
                       "height": H * OUT_SCALE, "data": base64.b64encode(data).decode()})
        if png_dir:
            os.makedirs(png_dir, exist_ok=True)
            with open(os.path.join(png_dir, f"{i + 1}-{file}"), "wb") as f:
                f.write(data)
    doc = {
        "format": "ui-flow",
        "version": 1,
        "name": "Kettle",
        "startScreen": "screen-1",
        "screens": [{"id": s.id, "name": s.name, "image": f"img-{i + 1}", "x": layout[s.id][0],
                     "y": layout[s.id][1], "scale": scale, "hotspots": s.hotspots}
                    for i, s in enumerate(screens)],
        "links": [{"id": f"link-{i + 1}", "from": f, **({"hotspot": h} if h else {}), "to": t, "message": m}
                  for i, (f, h, t, m) in enumerate(links)],
        "images": images,
    }
    doc["screens"][4]["notes"] = "Goes back to the menu by itself; Track order is not designed yet."
    with open(out, "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"wrote {out}")


def subset(src, out, screen_ids, drop_links=()):
    with open(src) as f:
        doc = json.load(f)
    keep = set(screen_ids)
    doc["screens"] = [s for s in doc["screens"] if s["id"] in keep]
    doc["links"] = [l for l in doc["links"]
                    if l["from"] in keep and l["to"] in keep and l["id"] not in drop_links]
    used = {s["image"] for s in doc["screens"]}
    doc["images"] = [i for i in doc["images"] if i["id"] in used]
    if doc["startScreen"] not in keep:
        doc["startScreen"] = doc["screens"][0]["id"]
    with open(out, "w") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    if len(sys.argv) >= 5 and sys.argv[1] == "--subset":
        subset(sys.argv[2], sys.argv[3], sys.argv[4].split(","),
               sys.argv[5].split(",") if len(sys.argv) > 5 else ())
    elif len(sys.argv) >= 2 and not sys.argv[1].startswith("-"):
        main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        sys.exit(__doc__)
