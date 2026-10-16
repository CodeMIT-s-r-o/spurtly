"""Spurtly mark: a timer ring of work dashes (coral) and rest dots (teal),
with an upward chevron in the middle.

Outputs into argv[1]:
  icon.png               1024 full-bleed, opaque (iOS, legacy Android)
  icon_background.png    1024 gradient only (Android adaptive background)
  icon_foreground.png    1024 mark on transparent, inside the adaptive safe zone
  icon_monochrome.png    same as foreground, white (Android 13 themed icon)
and argv[2]/logo.png     512 full-bleed copy for the in-app header.

Run from the project root:
  python3 tool/make_logo.py assets/icon assets/images
  dart run flutter_launcher_icons
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

out = Path(sys.argv[1])
app_images = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
app_images.mkdir(parents=True, exist_ok=True)

S = 4  # supersampling
N = 1024 * S

INK_TOP = np.array([0x1E, 0x26, 0x45])
INK_BOTTOM = np.array([0x0B, 0x0F, 0x1E])
CORAL_A, CORAL_B = (0xFF, 0x8A, 0x3D), (0xFF, 0x4D, 0x5E)
TEAL_A, TEAL_B = (0x5E, 0xEA, 0xD4), (0x14, 0xB8, 0xA6)


def background():
    y, x = np.mgrid[0:N, 0:N] / N
    t = np.clip(0.65 * y + 0.35 * x, 0, 1)[..., None]
    rgb = INK_TOP * (1 - t) + INK_BOTTOM * t
    return Image.fromarray(rgb.round().astype(np.uint8), "RGB").convert("RGBA")


def gradient_fill(mask, top, bottom, angle_deg=0):
    """Fill `mask` (L image) with a linear gradient top->bottom."""
    y, x = np.mgrid[0:N, 0:N] / N
    a = math.radians(angle_deg)
    t = np.clip((y * math.cos(a) + x * math.sin(a)), 0, 1)[..., None]
    rgb = np.array(top) * (1 - t) + np.array(bottom) * t
    img = Image.fromarray(rgb.round().astype(np.uint8), "RGB").convert("RGBA")
    img.putalpha(mask)
    return img


_Y, _X = np.mgrid[0:N, 0:N].astype(np.float32) + 0.5


def arc_mask(cx, cy, r, width, start, end):
    """Round-capped arc on the centre line of radius r - width/2.
    Angles in degrees, 0 = 12 o'clock, clockwise."""
    rc = r - width / 2
    dx, dy = _X - cx, _Y - cy
    ang = (np.degrees(np.arctan2(dx, -dy)) + 360) % 360
    dist = np.abs(np.hypot(dx, dy) - rc)
    span = (end - start) % 360
    inside = ((ang - start) % 360) <= span
    m = inside & (dist <= width / 2)
    for a in (start, end):
        px = cx + rc * math.sin(math.radians(a))
        py = cy - rc * math.cos(math.radians(a))
        m |= np.hypot(_X - px, _Y - py) <= width / 2
    return Image.fromarray((m * 255).astype(np.uint8), "L")


def mark(scale=1.0):
    """The ring + chevron as an RGBA layer, `scale` relative to full icon."""
    layer = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    cx = cy = N / 2
    r = 340 * S * scale  # outer radius
    w = 100 * S * scale  # stroke
    # Work = coral dashes, rest = teal dots, alternating three times and
    # mirror-symmetric: work centred at 60/180/300 deg, rest at 0/120/240, so
    # one rest dot sits right above the chevron. Caps fit inside each
    # segment's angle, so `gap` is the visible gap.
    cap_deg = math.degrees((w / 2) / (r - w / 2))
    work_len, rest_len = 80.0, 2 * cap_deg
    gap = (360 - 3 * (work_len + rest_len)) / 6
    angle = 60 - work_len / 2
    for is_work, length in [(True, work_len), (False, rest_len)] * 3:
        start = angle + cap_deg
        end = angle + length - cap_deg
        m = arc_mask(cx, cy, r, w, start, end)
        a, b = (CORAL_A, CORAL_B) if is_work else (TEAL_A, TEAL_B)
        layer.alpha_composite(gradient_fill(m, a, b))
        angle += length + gap

    # Chevron pointing up.
    cw = 150 * S * scale  # half width
    ch = 92 * S * scale  # height
    sw = 86 * S * scale  # stroke
    oy = 18 * S * scale  # optical lift
    pts = [(cx - cw, cy + ch / 2 - oy), (cx, cy - ch / 2 - oy), (cx + cw, cy + ch / 2 - oy)]
    m = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(m)
    d.line(pts, fill=255, width=int(sw), joint="curve")
    for px, py in (pts[0], pts[2]):
        d.ellipse((px - sw / 2, py - sw / 2, px + sw / 2, py + sw / 2), fill=255)
    chevron = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    chevron.putalpha(m)
    layer.alpha_composite(chevron)
    return layer


def down(img):
    return img.resize((1024, 1024), Image.LANCZOS)


bg = background()
full = bg.copy()
full.alpha_composite(mark(1.0))
down(full).convert("RGB").save(out / "icon.png")
full.convert("RGB").resize((512, 512), Image.LANCZOS).save(app_images / "logo.png")
down(bg).convert("RGB").save(out / "icon_background.png")

# Adaptive icons: the ring's outer diameter (680 of 1024) must sit inside the
# 66/108 safe-zone circle (626 of 1024).
fg = down(mark(0.88))
fg.save(out / "icon_foreground.png")
mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
mono.putalpha(fg.getchannel("A"))
mono.save(out / "icon_monochrome.png")
print("ok")
