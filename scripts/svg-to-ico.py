#!/usr/bin/env python3
"""svg-to-ico.py <icon.svg> <out.ico> - renders the SVG at the usual Windows icon sizes
(rsvg-convert) and packs them into one .ico (Pillow)."""
import io
import subprocess
import sys

from PIL import Image

src, out = sys.argv[1], sys.argv[2]
sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
images = []
for size in sizes:
    png = subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), src],
                         check=True, capture_output=True).stdout
    images.append(Image.open(io.BytesIO(png)).convert("RGBA"))
images[-1].save(out, format="ICO", sizes=[(s, s) for s in sizes], append_images=images[:-1])
