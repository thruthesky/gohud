# -*- coding: utf-8 -*-
"""Turns the website shots into the WebP files the pages show.

    bash <godot skill>/scripts/xvfb_run.sh --path <project> --out /tmp/shots --size 780x1688 \\
        -s res://addons/gohud/tests/site_widget_shots.gd
    python3 addons/gohud/tools/site_images.py /tmp/shots          # → www/img/{widgets,popups,presets}/ + shots.json

## What it writes
| From | To | Size |
|---|---|---|
| `widgets/<name>.png` cropped to one widget | `www/img/widgets/<name>.webp` | as shot (twice the UI units, sharp on a retina screen) |
| a whole phone screen (780×1688) anywhere | the same folder | 600 px wide — shown at most ~300 px wide on the site |
| `popups/look-*.png` | also `www/img/widgets/goui.webp`, the ten looks side by side | 5 × 2 grid |
| `widgets/skin-*.png` | also `www/img/widgets/goskin.webp`, the five skins stacked | as shot |
| — | `www/img/shots.json` | `{"widgets/gobar.webp": [382, 135], …}` — the **display** size (half the pixels) |

🔑 The pages read `shots.json` for `width`/`height`, so the layout does not jump while a picture loads, and the
   generators (`tools/site_catalog.py`) need no image library.
🛑 Needs Pillow (`pip install pillow`) — only here, never on the site.
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WWW = os.path.normpath(os.path.join(HERE, "..", "www"))
IMG = os.path.join(WWW, "img")
MANIFEST = os.path.join(IMG, "shots.json")
FOLDERS = ("widgets", "popups", "presets")
# A whole phone screen is scaled to this width; a cropped widget keeps its pixels.
SCREEN_WIDTH = 600
QUALITY = 84


def is_screen(image):
    return image.width >= 760 and image.height >= 1600


def save(image, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.convert("RGB").save(path, "WEBP", quality=QUALITY, method=6)


def fit(image):
    if is_screen(image):
        height = round(image.height * SCREEN_WIDTH / image.width)
        return image.resize((SCREEN_WIDTH, height), Image.LANCZOS)
    return image


def grid(images, columns, gap=16, back=(128, 128, 128)):
    """Pictures of one size in rows — for the looks overview."""
    w, h = images[0].size
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * w + (columns - 1) * gap, rows * h + (rows - 1) * gap), back)
    for i, image in enumerate(images):
        sheet.paste(image, ((i % columns) * (w + gap), (i // columns) * (h + gap)))
    return sheet


def stack(images, gap=0):
    width = max(image.width for image in images)
    sheet = Image.new("RGB", (width, sum(image.height for image in images) + gap * (len(images) - 1)), (0, 0, 0))
    y = 0
    for image in images:
        sheet.paste(image, (0, y))
        y += image.height + gap
    return sheet


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: site_images.py <shot folder>")
    shots = sys.argv[1]
    manifest = {}
    if os.path.isfile(MANIFEST):
        manifest = json.load(open(MANIFEST, encoding="utf-8"))
    written = 0
    for folder in FOLDERS:
        source = os.path.join(shots, folder)
        if not os.path.isdir(source):
            continue
        for name in sorted(os.listdir(source)):
            if not name.endswith(".png"):
                continue
            image = fit(Image.open(os.path.join(source, name)))
            rel = "%s/%s.webp" % (folder, name[:-4])
            save(image, os.path.join(IMG, rel))
            # The display size is half the pixels: twice the UI units for a crop, 300 px wide for a screen.
            manifest[rel] = [image.width // 2, image.height // 2]
            written += 1

    # The ten looks side by side, for GoUi · GoThemePresets.
    looks = sorted(f for f in os.listdir(os.path.join(shots, "popups")) if f.startswith("look-")) \
        if os.path.isdir(os.path.join(shots, "popups")) else []
    if looks:
        tiles = [Image.open(os.path.join(shots, "popups", f)).resize((260, 563), Image.LANCZOS) for f in looks]
        sheet = grid(tiles, 5)
        save(sheet, os.path.join(IMG, "widgets", "goui.webp"))
        manifest["widgets/goui.webp"] = [sheet.width // 2, sheet.height // 2]
        written += 1
    # The skins stacked, for GoSkin.
    skins = sorted(f for f in os.listdir(os.path.join(shots, "widgets")) if f.startswith("skin-")) \
        if os.path.isdir(os.path.join(shots, "widgets")) else []
    if skins:
        sheet = stack([Image.open(os.path.join(shots, "widgets", f)) for f in skins])
        save(sheet, os.path.join(IMG, "widgets", "goskin.webp"))
        manifest["widgets/goskin.webp"] = [sheet.width // 2, sheet.height // 2]
        written += 1

    with open(MANIFEST, "w", encoding="utf-8") as out:
        json.dump(dict(sorted(manifest.items())), out, indent=0, separators=(",", ":"))
        out.write("\n")
    total = sum(os.path.getsize(os.path.join(IMG, rel)) for rel in manifest if os.path.isfile(os.path.join(IMG, rel)))
    print("site images: %d written · %d in shots.json · %.1f MB → %s" % (written, len(manifest), total / 1e6, IMG))


if __name__ == "__main__":
    main()
