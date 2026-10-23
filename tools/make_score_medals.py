"""Generate arcade_light's numbered award medals as scalable, glossy vector art.

The skin exposes them as widget_art("medal_gold"), "medal_silver" and "medal_bronze".
The numerals are paths, so a platform font or locale cannot alter the artwork.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1] / "assets/arcade_light/score"
MEDALS = {
    "gold": ("#fff388", "#ffd231", "#e5a30b", "#f33238", "#ffb91e",
             "M29 23 L36 18 L41 18 L41 43 L47 43 L47 49 L28 49 L28 43 L34 43 L34 27 L29 30 Z"),
    "silver": ("#f6fbff", "#c7d6ed", "#7d96bd", "#2477ed", "#f0f7ff",
               "M28 27 C28 14 49 14 49 27 C49 34 41 37 35 43 L50 43 L50 49 L27 49 L27 44 C27 37 42 32 42 27 C42 21 34 21 34 27 Z"),
    "bronze": ("#ffcf85", "#f49b38", "#c65e19", "#29bd48", "#ffbe72",
               "M28 24 C33 15 49 16 49 27 C49 31 47 34 43 35 C53 38 52 51 38 51 C32 51 28 49 25 45 L30 41 C34 47 44 46 44 41 C44 37 38 37 34 37 L34 31 C39 31 43 31 43 27 C43 22 35 21 32 27 Z"),
}


def render(name, colors):
    top, middle, bottom, ribbon, number, path = colors
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="76" height="94" viewBox="0 0 76 94">
<defs>
<linearGradient id="face" x1="0" y1="0" x2="0.6" y2="1"><stop stop-color="{top}"/><stop offset="0.5" stop-color="{middle}"/><stop offset="1" stop-color="{bottom}"/></linearGradient>
<linearGradient id="shine" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#fff" stop-opacity=".85"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
</defs>
<g stroke="#101d4b" stroke-width="4" stroke-linejoin="round">
<path d="M23 52 L13 85 L25 79 L32 89 L40 58 Z" fill="{ribbon}"/>
<path d="M38 57 L45 89 L52 79 L65 85 L53 52 Z" fill="{ribbon}"/>
<path d="M26 60 L20 79 L25 76 L30 83 L35 62 M43 63 L48 82 L52 76 L58 79 L51 60" fill="none" stroke="#fff" stroke-opacity=".6" stroke-width="2"/>
<circle cx="38" cy="35" r="30" fill="{bottom}"/>
<circle cx="38" cy="33" r="28" fill="url(#face)"/>
<circle cx="38" cy="33" r="22" fill="none" stroke="{top}" stroke-width="2"/>
<path d="M17 25 C21 11 45 7 56 20" fill="none" stroke="#fff" stroke-width="4" stroke-linecap="round"/>
<ellipse cx="38" cy="22" rx="19" ry="11" fill="url(#shine)" stroke="none"/>
<path d="{path}" fill="{number}" stroke="{bottom}" stroke-width="2.5"/>
</g></svg>\n'''


def arrow(direction):
    degrees = {"up": 0, "right": 90, "down": 180, "left": 270}[direction]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">
<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#effbff"/><stop offset="1" stop-color="#9ed7ff"/></linearGradient></defs>
<rect x=".8" y=".8" width="16.4" height="16.4" rx="4" fill="url(#g)" stroke="#183670" stroke-width="1.6"/>
<path d="M3 6 Q3 3 6 3 H12" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round"/>
<path d="M9 4.5 L14 11.5 Q14.5 12.5 13 12.5 H5 Q3.5 12.5 4 11.5 Z" fill="#10194c" stroke="#fff" stroke-width=".7" stroke-linejoin="round" transform="rotate({degrees} 9 9)"/>
</svg>\n'''


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    check = "--check" in sys.argv
    artwork = {f"medal_{name}": render(name, colors) for name, colors in MEDALS.items()}
    artwork.update({f"scroll_{direction}": arrow(direction) for direction in ("up", "down", "left", "right")})
    for name, source in artwork.items():
        path = ROOT / f"{name}.svg"
        if check:
            if not path.is_file() or path.read_text() != source:
                raise SystemExit(f"stale medal artwork: {path}")
        else:
            path.write_text(source)
