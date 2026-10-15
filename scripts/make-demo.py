#!/usr/bin/env python3
"""make-demo.py <out.json> - writes a small sample ui-flow app with drawn mock screens
(a phone app: login, home, settings, ...), used by the smoke test and as an example."""
import base64
import io
import json
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 780, 1688  # 390 x 844 @2x
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
INK, MUTED, LINE, ACCENT, BG = (30, 30, 30), (120, 120, 120), (225, 225, 225), (13, 153, 255), (255, 255, 255)


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else FONT, size)


class Screen:
    def __init__(self, sid, name, title):
        self.id, self.name = sid, name
        self.img = Image.new("RGB", (W, H), BG)
        self.d = ImageDraw.Draw(self.img)
        self.hotspots = []
        self.d.text((60, 70), "9:41", font=font(30, True), fill=INK)
        self.d.text((60, 190), title, font=font(60, True), fill=INK)

    def text(self, xy, s, size=34, color=INK, bold=False):
        self.d.text(xy, s, font=font(size, bold), fill=color)

    def field(self, y, label):
        self.text((60, y), label, 28, MUTED)
        self.d.rounded_rectangle((60, y + 44, W - 60, y + 144), 24, outline=LINE, width=3)

    def button(self, y, label, hid, name, primary=True, h=110):
        box = (60, y, W - 60, y + h)
        if primary:
            self.d.rounded_rectangle(box, 30, fill=ACCENT)
        else:
            self.d.rounded_rectangle(box, 30, outline=ACCENT, width=3)
        f = font(36, True)
        tw = self.d.textlength(label, font=f)
        self.d.text(((W - tw) / 2, y + h / 2 - 22), label, font=f, fill=BG if primary else ACCENT)
        return self.hot(hid, name, box)

    def row(self, y, label, hid, name):
        box = (40, y, W - 40, y + 120)
        self.d.line((60, y + 120, W - 60, y + 120), fill=LINE, width=2)
        self.text((60, y + 38), label, 38)
        self.text((W - 100, y + 30), ">", 44, MUTED)
        return self.hot(hid, name, box)

    def back(self, hid):
        self.text((50, 120), "<  Back", 32, ACCENT)
        return self.hot(hid, "Back", (40, 110, 260, 170))

    def hot(self, hid, name, box):
        x0, y0, x1, y1 = box
        self.hotspots.append({"id": hid, "name": name, "x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0})
        return hid

    def png(self):
        buf = io.BytesIO()
        self.img.save(buf, "PNG", optimize=True)
        return buf.getvalue()


def main(out):
    login = Screen("screen-1", "Login", "Welcome back")
    login.text((60, 290), "Sign in to continue", 34, MUTED)
    login.field(420, "Email")
    login.field(620, "Password")
    login.button(860, "Sign in", "hotspot-1", "Sign in")
    login.text((60, 1020), "Forgot password?", 32, ACCENT)
    login.hot("hotspot-2", "Forgot password", (50, 1005, 360, 1065))
    login.button(1450, "Create account", "hotspot-3", "Create account", primary=False)

    home = Screen("screen-2", "Home", "Home")
    home.text((60, 290), "Good morning, Alex", 34, MUTED)
    home.row(400, "Profile", "hotspot-4", "Profile")
    home.row(520, "Settings", "hotspot-5", "Settings")
    home.row(640, "Messages", "hotspot-6", "Messages")
    home.d.rounded_rectangle((60, 1480, W - 60, 1590), 30, fill=(245, 245, 245))
    home.text((100, 1515), "Type a command…", 34, MUTED)

    settings = Screen("screen-3", "Settings", "Settings")
    settings.back("hotspot-7")
    for i, label in enumerate(["Notifications", "Dark mode", "Language"]):
        settings.text((60, 420 + i * 120), label, 38)
        settings.d.rounded_rectangle((W - 190, 410 + i * 120, W - 60, 480 + i * 120), 35,
                                     fill=ACCENT if i != 1 else LINE)
    settings.button(1450, "Log out", "hotspot-8", "Log out", primary=False)

    profile = Screen("screen-4", "Profile", "Alex Doe")
    profile.back("hotspot-9")
    profile.d.ellipse((60, 320, 260, 520), fill=(200, 225, 255))
    profile.text((300, 380), "alex@example.com", 34, MUTED)

    help_ = Screen("screen-5", "Help", "Help")
    help_.back("hotspot-10")
    for i, line in enumerate(["help      show this list", "settings  open settings", "logout    sign out"]):
        help_.text((60, 420 + i * 80), line, 32)

    reset = Screen("screen-6", "Reset password", "Reset password")
    reset.back("hotspot-11")
    reset.field(420, "Email")
    reset.button(640, "Send link", "hotspot-12", "Send link")

    layout = {  # canvas positions
        "screen-1": (0, 0), "screen-2": (600, 0), "screen-3": (1200, -440), "screen-4": (1200, 540),
        "screen-5": (1800, 0), "screen-6": (-600, 0),
    }
    screens = [login, home, settings, profile, help_, reset]
    scale = round(720 / H, 4)
    links = [
        ("screen-1", "hotspot-1", "screen-2", ""),
        ("screen-1", "hotspot-2", "screen-6", ""),
        ("screen-2", "hotspot-4", "screen-4", ""),
        ("screen-2", "hotspot-5", "screen-3", ""),
        ("screen-2", "", "screen-5", "user types command help"),
        ("screen-3", "hotspot-7", "screen-2", ""),
        ("screen-3", "hotspot-8", "screen-1", ""),
        ("screen-4", "hotspot-9", "screen-2", ""),
        ("screen-5", "hotspot-10", "screen-2", ""),
        ("screen-6", "hotspot-11", "screen-1", ""),
        ("screen-6", "hotspot-12", "screen-1", "after the email is sent"),
    ]
    doc = {
        "format": "ui-flow",
        "version": 1,
        "name": "Demo app",
        "startScreen": "screen-1",
        "screens": [
            {"id": s.id, "name": s.name, "image": "img-" + s.id.split("-")[1],
             "x": layout[s.id][0], "y": layout[s.id][1], "scale": scale, "hotspots": s.hotspots}
            for s in screens
        ],
        "links": [{"id": f"link-{i + 1}", "from": f, **({"hotspot": h} if h else {}), "to": t, "message": m}
                  for i, (f, h, t, m) in enumerate(links)],
        "images": [
            {"id": "img-" + s.id.split("-")[1], "file": s.name.lower().replace(" ", "-") + ".png",
             "mime": "image/png", "width": W, "height": H, "data": base64.b64encode(s.png()).decode()}
            for s in screens
        ],
    }
    with open(out, "w") as f:
        json.dump(doc, f, indent=2)
        f.write("\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "demo.json")
