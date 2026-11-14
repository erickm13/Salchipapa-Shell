#!/usr/bin/env python3
"""Suggest a theme for each animated wallpaper (Wallpaper Engine) from the colours of its preview.

For every animated wallpaper without an assignment in ~/.config/salchipapa-shell/animated-themes.json,
the preview is reduced to its main colours and compared (in CIE Lab) with each theme's palette in
shell/themes/schemes.json (accents, surfaces and the 16 terminal colours). The theme with the
smallest weighted distance wins. Existing assignments (the user's corrections) are never touched.

Usage: scripts/classify-animated.py            (only the ones without a theme)
       scripts/classify-animated.py --redo     (all again, except the ones marked by hand)
       scripts/classify-animated.py --report   (how many per theme, without writing)
       scripts/classify-animated.py --set <id> <theme>   (a correction by hand: kept by --redo)
"""
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
SCHEMES = REPO / "shell/themes/schemes.json"
MAP = Path.home() / ".config/salchipapa-shell/animated-themes.json"
ROLES = ["primary", "secondary", "tertiary", "error", "onSurface", "onSurfaceVariant",
         "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh"] + [f"term{i}" for i in range(1, 15)]
SKIP = {"dynamic"}


def lab(rgb):
    def lin(c):
        c /= 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(float(c)) for c in rgb)
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def hexlab(h):
    return lab(tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)))


def palettes():
    data = json.loads(SCHEMES.read_text())
    out = {}
    for name, flavours in data.items():
        if name in SKIP:
            continue
        c = next(iter(flavours.values()))
        out[name] = [hexlab(c[r]) for r in ROLES if r in c]
    return out


def image_colours(path, n=12):
    im = Image.open(path)
    im.seek(0)  # first frame of a gif
    im = im.convert("RGB").resize((64, 64))
    q = im.quantize(colors=n, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()
    counts = q.getcolors()
    total = sum(c for c, _ in counts)
    return [(c / total, lab(pal[i * 3:i * 3 + 3])) for c, i in counts]


def score(colours, pal):
    d = lambda a, b: sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5
    return sum(w * min(d(c, p) for p in pal) for w, c in colours)


def set_theme(wid, theme):
    current = json.loads(MAP.read_text()) if MAP.exists() else {}
    current[wid] = theme
    manual = set(current.get("_manual", [])) | {wid}
    current["_manual"] = sorted(manual)
    MAP.parent.mkdir(parents=True, exist_ok=True)
    MAP.write_text(json.dumps(current, indent=1, ensure_ascii=False) + "\n")


def main():
    if sys.argv[1:2] == ["--set"]:
        set_theme(sys.argv[2], sys.argv[3])
        return
    redo, report = "--redo" in sys.argv, "--report" in sys.argv
    walls = json.loads(subprocess.run([str(REPO / "scripts/animated-wallpaper.sh"), "list"],
                                      capture_output=True, text=True, check=True).stdout)
    current = json.loads(MAP.read_text()) if MAP.exists() else {}
    manual = set(current.get("_manual", []))
    pals = palettes()
    result = dict(current)
    for w in walls:
        wid = w["id"]
        if wid in current and (not redo or wid in manual):
            continue
        try:
            colours = image_colours(w["preview"])
        except Exception:
            continue
        result[wid] = min(pals, key=lambda t: score(colours, pals[t]))
    counts = {}
    for k, v in result.items():
        if not k.startswith("_"):
            counts[v] = counts.get(v, 0) + 1
    print(json.dumps(counts, indent=1))
    if not report:
        MAP.parent.mkdir(parents=True, exist_ok=True)
        MAP.write_text(json.dumps(result, indent=1, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
