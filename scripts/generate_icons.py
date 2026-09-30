#!/usr/bin/env python3
"""Generate the Molten Merge app icon set into Assets.xcassets/AppIcon.appiconset.

The icon shows three glowing molten-glass blobs (ember orange, ocean blue,
violet — the first three merge tiers) fusing together over the dark studio
backdrop with its furnace glow. Pure PIL, no assets.
"""
from PIL import Image, ImageDraw, ImageFilter
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
OUT = HERE / "MoltenMerge" / "Assets.xcassets" / "AppIcon.appiconset"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_icon(size):
    img = Image.new("RGB", (size, size))
    d = ImageDraw.Draw(img)
    # Background: deep blue-black top -> warm dark brown bottom.
    top, bottom = (10, 10, 20), (26, 15, 8)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, y / size))

    # Furnace glow near the bottom: blurred orange ellipse on its own layer.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([size * 0.05, size * 0.62, size * 0.95, size * 1.10],
               fill=(255, 110, 30, 110))
    glow = glow.filter(ImageFilter.GaussianBlur(size // 8))
    img.paste(glow, (0, 0), glow)

    def orb(cx, cy, r, color):
        # Halo: blurred color disc.
        halo = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        hd = ImageDraw.Draw(halo)
        hd.ellipse([cx - r * 1.6, cy - r * 1.6, cx + r * 1.6, cy + r * 1.6],
                   fill=color + (90,))
        halo = halo.filter(ImageFilter.GaussianBlur(int(r * 0.5)))
        img.paste(halo, (0, 0), halo)
        # Body: layered discs, saturated edge -> bright core.
        for mult, col in ((1.0, color), (0.72, lerp(color, (255, 255, 255), 0.25)),
                          (0.42, lerp(color, (255, 255, 255), 0.55)),
                          (0.20, (255, 255, 255))):
            rr = r * mult
            d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=col)
        # Rim light crescent, upper-left.
        d.arc([cx - r * 0.92, cy - r * 0.92, cx + r * 0.92, cy + r * 0.92],
              start=135, end=225, fill=(255, 255, 255, 200), width=max(3, size // 200))
        # Specular dot.
        sr = r * 0.16
        d.ellipse([cx - r * 0.38 - sr, cy - r * 0.42 - sr,
                   cx - r * 0.38 + sr, cy - r * 0.42 + sr],
                  fill=(255, 255, 255, 235))

    # Three blobs mid-merge: spark (orange), droplet (blue), orb (violet).
    orb(int(size * 0.36), int(size * 0.52), int(size * 0.155), (255, 115, 30))
    orb(int(size * 0.64), int(size * 0.46), int(size * 0.175), (40, 140, 245))
    orb(int(size * 0.52), int(size * 0.66), int(size * 0.125), (140, 80, 245))

    # Rounded-corner mask (iOS squircle approximation).
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size, size],
                                           radius=int(size * 0.225), fill=255)
    img.putalpha(mask)
    bg = Image.new("RGBA", (size, size), (10, 10, 20, 255))
    bg.paste(img, (0, 0), img)
    return bg.convert("RGB")


SIZES = [
    ("Icon-20@2x.png", 40, "20x20", "2x"),
    ("Icon-20@3x.png", 60, "20x20", "3x"),
    ("Icon-29@2x.png", 58, "29x29", "2x"),
    ("Icon-29@3x.png", 87, "29x29", "3x"),
    ("Icon-40@2x.png", 80, "40x40", "2x"),
    ("Icon-40@3x.png", 120, "40x40", "3x"),
    ("Icon-60@2x.png", 120, "60x60", "2x"),
    ("Icon-60@3x.png", 180, "60x60", "3x"),
    ("Icon-1024.png", 1024, "1024x1024", "1x"),
]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    master = draw_icon(1024)
    images = []
    for filename, px, size_str, scale in SIZES:
        icon = master.resize((px, px), Image.LANCZOS)
        icon.save(OUT / filename)
        images.append({"filename": filename, "idiom": "iphone",
                       "scale": scale, "size": size_str})
    (OUT / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print("wrote", len(images), "icons to", OUT)


if __name__ == "__main__":
    main()
