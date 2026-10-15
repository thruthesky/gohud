# -*- coding: utf-8 -*-
"""Compare two screenshots pixel by pixel: how much differs, where, and a picture of it.

    python3 addons/gohud/tools/pixel_diff.py a.png b.png                       # prints the % of pixels that differ
    python3 addons/gohud/tools/pixel_diff.py a.png b.png --out sheet.png       # + a  a | b | heatmap  sheet
    python3 addons/gohud/tools/pixel_diff.py a.png b.png --tolerance 8 --max-percent 0.5 --json

Exit code: 0 when the difference is at most `--max-percent` (default 0), 1 when it is more, 2 when an image cannot be
read. Needs Pillow (`pip install pillow`); nothing else, so it runs wherever the screenshots are.

## Why a tolerance
Two renders of the *same* look are rarely bit-identical: text anti-aliasing, a sub-pixel offset, a GPU driver's
rounding. A pixel counts as different only when one of its channels (R, G, B or A) moves by more than `--tolerance`
(0-255, default 8, about 3%) — small enough that a wrong colour, a missing outline or a shifted edge still counts,
large enough that rounding does not.

## What "differ" means for two sizes
When the images are not the same size, both are laid on the larger canvas from the top-left corner and the part only
one of them covers counts as differing: a widget that grew by ten pixels is a difference, not an error.

## The heatmap
The first image in grey, dimmed, with every differing pixel painted red — brighter the bigger the change. Used from
Python, `compare()` returns the numbers and `sheet()` the side-by-side picture, so another tool (a parity harness, a
screenshot test) can build its own report on them.
"""
import argparse
import json
import os
import sys

try:
    from PIL import Image, ImageChops, ImageDraw
except ImportError:  # the CLI says so in one line instead of a traceback
    Image = None

DEFAULT_TOLERANCE = 8
# The red a differing pixel is painted in, and the dim grey under it. The grey is dimmed so the red reads on any
# screenshot, light or dark.
HEAT_RED = (255, 32, 32)
BASE_DIM = 0.45
LABEL_BAR = 28  # height of the caption strip above each image in a sheet


class Result:
    """The outcome of one comparison."""

    def __init__(self, differing, total, max_delta, bbox, size_a, size_b, heatmap):
        self.differing = differing      # pixels over the tolerance (plus those only one image covers)
        self.total = total              # pixels of the common canvas
        self.max_delta = max_delta      # the largest channel change seen (0-255)
        self.bbox = bbox                # (left, top, right, bottom) around every differing pixel, or None
        self.size_a = size_a
        self.size_b = size_b
        self.heatmap = heatmap          # PIL image, RGB

    @property
    def percent(self):
        return 100.0 * self.differing / self.total if self.total else 0.0

    def as_dict(self):
        return {"percent": round(self.percent, 4), "differing": self.differing, "total": self.total,
                "max_delta": self.max_delta, "bbox": list(self.bbox) if self.bbox else None,
                "size_a": list(self.size_a), "size_b": list(self.size_b)}


def _on_canvas(img, size):
    """`img` as RGBA on a transparent canvas of `size`, top-left aligned."""
    img = img.convert("RGBA")
    if img.size == size:
        return img
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.paste(img, (0, 0))
    return canvas


def _coverage(img, size):
    """A mask (L) of where `img` covers the common canvas: 255 inside it, 0 in the padding."""
    m = Image.new("L", size, 0)
    m.paste(255, (0, 0, img.size[0], img.size[1]))
    return m


def compare(a, b, tolerance=DEFAULT_TOLERANCE):
    """Compares two PIL images (or paths). Returns a Result."""
    if isinstance(a, str):
        a = Image.open(a)
    if isinstance(b, str):
        b = Image.open(b)
    size = (max(a.size[0], b.size[0]), max(a.size[1], b.size[1]))
    ca, cb = _on_canvas(a, size), _on_canvas(b, size)
    # The largest change over the four channels, per pixel: ImageChops works in C, so a 2388x1668 pair takes
    # milliseconds instead of the seconds a Python loop would.
    delta = None
    for ch_a, ch_b in zip(ca.split(), cb.split()):
        d = ImageChops.difference(ch_a, ch_b)
        delta = d if delta is None else ImageChops.lighter(delta, d)
    over = delta.point(lambda v: 255 if v > tolerance else 0)
    if a.size != b.size:
        # Where only one image covers the canvas, the two differ whatever the pixels say.
        only_one = ImageChops.difference(_coverage(a, size), _coverage(b, size))
        over = ImageChops.lighter(over, only_one)
        delta = ImageChops.lighter(delta, only_one)
    differing = over.histogram()[255]
    max_delta = delta.getextrema()[1]
    bbox = over.getbbox()
    # Heatmap: the first image in dimmed grey, red where it differs, the red's strength following the change.
    grey = ca.convert("L").point(lambda v: int(v * BASE_DIM))
    base = Image.merge("RGB", (grey, grey, grey))
    strength = ImageChops.multiply(delta.point(lambda v: min(255, 96 + v * 2)), over)
    heat = Image.composite(Image.new("RGB", size, HEAT_RED), base, strength)
    return Result(differing, size[0] * size[1], max_delta, bbox, a.size, b.size, heat)


def sheet(images, labels, background=(24, 24, 28), gap=12):
    """The images side by side on one canvas, each under a caption. `images` are PIL images or paths; a None
    becomes an empty grey frame of the first image's size (a side that has nothing to show)."""
    imgs = [Image.open(i) if isinstance(i, str) else i for i in images]
    ref = next((i for i in imgs if i is not None), None)
    if ref is None:
        raise ValueError("sheet() needs at least one image")
    imgs = [i if i is not None else Image.new("RGB", ref.size, (60, 60, 66)) for i in imgs]
    w = sum(i.size[0] for i in imgs) + gap * (len(imgs) + 1)
    h = max(i.size[1] for i in imgs) + LABEL_BAR + gap * 2
    out = Image.new("RGB", (w, h), background)
    draw = ImageDraw.Draw(out)
    x = gap
    for img, label in zip(imgs, labels):
        draw.text((x, gap), label, fill=(235, 235, 240))
        out.paste(img.convert("RGB"), (x, gap + LABEL_BAR))
        x += img.size[0] + gap
    return out


def stack(sheets, background=(24, 24, 28)):
    """Sheets one under the other (one row per screen size, for example)."""
    w = max(s.size[0] for s in sheets)
    h = sum(s.size[1] for s in sheets)
    out = Image.new("RGB", (w, h), background)
    y = 0
    for s in sheets:
        out.paste(s, (0, y))
        y += s.size[1]
    return out


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("a")
    p.add_argument("b")
    p.add_argument("--tolerance", type=int, default=DEFAULT_TOLERANCE,
                   help="per-channel change (0-255) still counted as equal (default %d)" % DEFAULT_TOLERANCE)
    p.add_argument("--max-percent", type=float, default=0.0, help="exit 1 above this %% of differing pixels")
    p.add_argument("--out", help="write an  a | b | heatmap  sheet here")
    p.add_argument("--heatmap", help="write the heatmap alone here")
    p.add_argument("--json", action="store_true", help="print the result as JSON")
    args = p.parse_args(argv)
    if Image is None:
        print("🛑 pixel_diff.py needs Pillow: python3 -m pip install pillow", file=sys.stderr)
        return 2
    for path in (args.a, args.b):
        if not os.path.isfile(path):
            print("🛑 no such image: %s" % path, file=sys.stderr)
            return 2
    try:
        r = compare(args.a, args.b, args.tolerance)
    except OSError as e:
        print("🛑 cannot read an image: %s" % e, file=sys.stderr)
        return 2
    if args.heatmap:
        r.heatmap.save(args.heatmap)
    if args.out:
        sheet([args.a, args.b, r.heatmap],
              [os.path.basename(args.a), os.path.basename(args.b), "diff > %d" % args.tolerance]).save(args.out)
    if args.json:
        print(json.dumps(r.as_dict()))
    else:
        print("%.3f%% differ (%d of %d pixels, tolerance %d, largest change %d)%s"
              % (r.percent, r.differing, r.total, args.tolerance, r.max_delta,
                 "" if r.size_a == r.size_b else " — sizes %dx%d vs %dx%d" % (r.size_a + r.size_b)))
    return 0 if r.percent <= args.max_percent else 1


if __name__ == "__main__":
    sys.exit(main())
