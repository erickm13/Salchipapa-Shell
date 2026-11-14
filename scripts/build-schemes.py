#!/usr/bin/env python3
"""Rebuild the schemes in shell/themes/schemes.json that come from a known palette.

The schemes exported from caelestia (gruvbox, catppuccin, rosepine, onedark, oldworld) were
Material You palettes generated from a seed colour: they only kept a vague hue of the original
theme. This script writes them back from the official palettes, with the same keys as the
hand-made schemes (tokyonight, nord...). Schemes not listed here are left untouched.

Usage: scripts/build-schemes.py            (rewrites shell/themes/schemes.json)
       scripts/build-schemes.py --check    (exit 1 if the file is out of date)
"""
import json
import sys
from pathlib import Path

SCHEMES = Path(__file__).resolve().parent.parent / "shell/themes/schemes.json"


def rgb(h):
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def mix(a, b, t):
    """a blended toward b by t (0 = a, 1 = b)."""
    return "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(rgb(a), rgb(b)))


def build(p):
    """p: palette with bg, fg, the surface ladder, accents and 16 ANSI colours."""
    bg, fg, light = p["bg"], p["fg"], p.get("light", False)
    p_, s_, t_, err = p["primary"], p["secondary"], p["tertiary"], p["red"]
    # A palette can give its own darker accents ("dimmed") and container colour ("container")
    # so that every value comes from it; otherwise they are mixed.
    dim = lambda c: p.get("dimmed", {}).get(c) or mix(c, "000000", 0.15)
    cont = lambda c: p.get("container") or mix(bg, c, 0.22)
    cat = p.get("cat", {})
    ansi = p["ansi"]

    c = {
        "primary_paletteKeyColor": p_, "secondary_paletteKeyColor": s_,
        "tertiary_paletteKeyColor": t_, "neutral_paletteKeyColor": bg,
        "neutral_variant_paletteKeyColor": p["s2"],
        "background": bg, "onBackground": fg,
        "surface": p["s1"], "surfaceDim": p["dim"], "surfaceBright": p["s3"],
        "surfaceContainerLowest": p["lowest"], "surfaceContainerLow": p["s1"],
        "surfaceContainer": p["s2"], "surfaceContainerHigh": p["s3"],
        "surfaceContainerHighest": p["s4"],
        "onSurface": fg, "surfaceVariant": p["s2"], "onSurfaceVariant": p["sub"],
        "inverseSurface": fg, "inverseOnSurface": bg,
        "outline": p["muted"], "outlineVariant": p["s3"],
        "shadow": "000000", "scrim": "000000", "surfaceTint": p_,
    }
    for name, col in (("primary", p_), ("secondary", s_), ("tertiary", t_)):
        cap = name.capitalize()
        c[name] = col
        c[f"on{cap}"] = bg
        c[f"{name}Container"] = cont(col)
        c[f"on{cap}Container"] = col
        if name == "primary":
            c["inversePrimary"] = dim(col)
    c.update({"error": err, "onError": bg, "errorContainer": cont(err), "onErrorContainer": err})
    for name, col in (("primary", p_), ("secondary", s_), ("tertiary", t_)):
        cap = name.capitalize()
        c[f"{name}Fixed"] = col
        c[f"{name}FixedDim"] = dim(col)
        c[f"on{cap}Fixed"] = bg
        c[f"on{cap}FixedVariant"] = p["s2"]
    for i, col in enumerate(ansi):
        c[f"term{i}"] = col

    # Catppuccin-style names (catppuccin uses its own; the rest map from the accents)
    named = {
        "rosewater": p.get("rose", fg), "flamingo": p.get("pink", p["magenta"]),
        "pink": p.get("pink", p["magenta"]), "mauve": p["magenta"], "red": err,
        "maroon": p.get("maroon", err), "peach": p["orange"], "yellow": p["yellow"],
        "green": p["green"], "teal": p["cyan"], "sky": p.get("sky", p["cyan"]),
        "sapphire": p.get("sapphire", p["blue"]), "blue": p["blue"],
        "lavender": p.get("lavender", p["magenta"]),
    }
    named.update({k: v for k, v in cat.items() if k in named})
    c.update(named)
    c.update({
        "klink": p["blue"], "klinkSelection": p["blue"],
        "kvisited": p["magenta"], "kvisitedSelection": p["magenta"],
        "knegative": err, "knegativeSelection": err,
        "kneutral": p["yellow"], "kneutralSelection": p["yellow"],
        "kpositive": p["green"], "kpositiveSelection": p["green"],
    })
    ramp = {
        "text": fg, "subtext1": p["sub"], "subtext0": mix(p["sub"], p["muted"], 0.5),
        "overlay2": mix(p["muted"], p["sub"], 0.5), "overlay1": mix(p["muted"], p["sub"], 0.25),
        "overlay0": p["muted"], "surface2": p["s4"], "surface1": p["s3"], "surface0": p["s2"],
        "base": bg, "mantle": p["dim"], "crust": p["lowest"],
    }
    ramp.update({k: v for k, v in cat.items() if k in ramp})
    c.update(ramp)
    c.update({"success": p["green"], "onSuccess": bg,
              "successContainer": cont(p["green"]), "onSuccessContainer": fg})
    return {k: v.upper() for k, v in c.items()}


# --- Gruvbox (morhetz/gruvbox colours, laid out like ellisonleao/gruvbox.nvim) -------------
# Only colours from the palette. As in gruvbox.nvim, the contrast only changes bg0; the ladder
# above it is always dark1-dark4 (shell bg1-bg4 = cursorline/floats, statusline/pmenu, visual,
# line numbers). Accents: green (Directory/Function: the user's choice for the shell), blue
# (Identifier, PmenuSel, DiagnosticInfo), purple (Constant). Terminal colours are the ones gruvbox.nvim sets, except blue.
def gruvbox_(bg0):
    return build(dict(
        bg=bg0, dim=bg0, lowest=bg0, container="3C3836",
        s1="3C3836", s2="504945", s3="665C54", s4="7C6F64",
        fg="EBDBB2", sub="A89984", muted="928374",
        red="FB4934", green="B8BB26", yellow="FABD2F", blue="83A598", magenta="D3869B",
        cyan="8EC07C", orange="FE8019",
        primary="B8BB26", secondary="83A598", tertiary="D3869B",
        dimmed={"B8BB26": "98971A", "83A598": "458588", "D3869B": "B16286"},  # bright -> neutral
        cat={"subtext1": "D5C4A1", "subtext0": "BDAE93", "overlay2": "A89984",
             "overlay1": "928374", "overlay0": "7C6F64"},
        # Blue slots (4, 12) hold the gray (bright black) instead of blue: the user's choice.
        ansi=[bg0, "CC241D", "98971A", "D79921", "928374", "B16286", "689D6A", "A89984",
              "928374", "FB4934", "B8BB26", "FABD2F", "928374", "D3869B", "8EC07C", "EBDBB2"]))


gruvbox = {"hard": gruvbox_("1D2021"), "medium": gruvbox_("282828"), "soft": gruvbox_("32302F")}


# --- Solarized, as craftzdog/solarized-osaka.nvim with style = "vivid" (the user's and craftzdog's) -----------------
# Its own palette and terminal colours (extras/kitty, extras/foot). Accent = blue (Directory,
# Function), secondary = green (Keyword, Operator), tertiary = orange (Special, CursorLineNr).
# Surfaces: bg 001419, CursorLine 002c38, Visual/Pmenu/WinSeparator 063540; the two above are
# 063540 mixed toward the comment gray (osaka has no lighter dark background).
OSAKA_BG, OSAKA_S1, OSAKA_S2, OSAKA_MUTED = "001419", "002C38", "063540", "7B99A2"
solarized = {"default": build(dict(
    bg=OSAKA_BG, dim=OSAKA_BG, lowest=OSAKA_BG,
    s1=OSAKA_S1, s2=OSAKA_S2, s3=mix(OSAKA_S2, OSAKA_MUTED, 0.3), s4=mix(OSAKA_S2, OSAKA_MUTED, 0.55),
    fg="B6C5C6", sub="a0b4b6", muted=OSAKA_MUTED,
    red="FF6C6A", green="a2bb00", yellow="DBA500", blue="5AAEFA", magenta="FE67A8",
    cyan="34C5B9", orange="FB724A",
    primary="5AAEFA", secondary="a2bb00", tertiary="FB724A",
    cat={"subtext1": "C2CDCD", "subtext0": "a0b4b6", "overlay2": "85a1ac", "overlay1": "7B99A2",
         "overlay0": "7B99A2"},
    ansi=["001419", "FF6C6A", "a2bb00", "DBA500", "5AAEFA", "FE67A8", "34C5B9", "a0b4b6",
          "7B99A2", "FF6C6A", "a2bb00", "DBA500", "5AAEFA", "FE67A8", "34C5B9", "a0b4b6"]))}


# --- Gentleman Kanagawa Blur (Gentleman-Programming/gentleman-kanagawa-blur, variant "blur") -----
# Its palette and terminal colours (nvim's terminal_color_*). Accent = Directory (lavender), secondary
# = Keyword (lilac), tertiary = its accent (yellow: CursorLineNr, Search). Surfaces: CursorLine
# 191e28, Visual/PmenuSel 232a36, then its surface2 and gray3.
blur = {"default": build(dict(
    bg="06080F", dim="06080F", lowest="06080F",
    s1="191E28", s2="232A36", s3="2A3142", s4="313342",
    fg="F3F6F9", sub="A3B5C1", muted="8394A3",
    red="CB7C94", green="B7CC85", yellow="FFE066", blue="7FB4CA", magenta="B99BF2",
    cyan="7AA89F", orange="DEBA87", pink="FF8DD7",
    primary="A3B5D6", secondary="C99AD6", tertiary="E0C15A",
    cat={"subtext1": "A3B5C1", "subtext0": "8A8FA3", "overlay2": "8394A3", "overlay1": "5C6170",
         "overlay0": "5C6170", "lavender": "B99BF2"},
    ansi=["06080F", "CB7C94", "B7CC85", "FFE066", "7FB4CA", "A3B5D6", "7AA89F", "F3F6F9",
          "8A8FA3", "DE8FA8", "D1E8A9", "FFF7B1", "A3D4D5", "B99BF2", "7FB4CA", "F3F6F9"]))}


# --- Catppuccin (catppuccin/palette) -------------------------------------------------------
def catppuccin(cp, light=False):
    ansi = ([cp["subtext1"]] if light else [cp["surface1"]]) + [
        cp["red"], cp["green"], cp["yellow"], cp["blue"], cp["pink"], cp["teal"]] + (
        [cp["surface2"], cp["subtext0"]] if light else [cp["subtext1"], cp["surface2"]]) + [
        cp["red"], cp["green"], cp["yellow"], cp["blue"], cp["pink"], cp["teal"]] + (
        [cp["surface1"]] if light else [cp["subtext0"]])
    return build(dict(
        light=light, bg=cp["base"], fg=cp["text"], sub=cp["subtext1"], muted=cp["overlay0"],
        dim=cp["mantle"], lowest=cp["crust"],
        s1=cp["surface0"], s2=cp["surface0"], s3=cp["surface1"], s4=cp["surface2"],
        red=cp["red"], green=cp["green"], yellow=cp["yellow"], blue=cp["blue"],
        magenta=cp["mauve"], cyan=cp["teal"], orange=cp["peach"],
        primary=cp["mauve"], secondary=cp["blue"], tertiary=cp["pink"],
        ansi=ansi, cat=cp))


def cp(s):
    keys = ("rosewater flamingo pink mauve red maroon peach yellow green teal sky sapphire blue "
            "lavender text subtext1 subtext0 overlay2 overlay1 overlay0 surface2 surface1 "
            "surface0 base mantle crust").split()
    return dict(zip(keys, s.split()))


catppuccin_ = {
    "latte": catppuccin(cp(
        "dc8a78 dd7878 ea76cb 8839ef d20f39 e64553 fe640b df8e1d 40a02b 179299 04a5e5 209fb5 "
        "1e66f5 7287fd 4c4f69 5c5f77 6c6f85 7c7f93 8c8fa1 9ca0b0 acb0be bcc0cc ccd0da eff1f5 "
        "e6e9ef dce0e8"), light=True),
    "frappe": catppuccin(cp(
        "f2d5cf eebebe f4b8e4 ca9ee6 e78284 ea999c ef9f76 e5c890 a6d189 81c8be 99d1db 85c1dc "
        "8caaee babbf1 c6d0f5 b5bfe2 a5adce 949cbb 838ba7 737994 626880 51576d 414559 303446 "
        "292c3c 232634")),
    "macchiato": catppuccin(cp(
        "f4dbd6 f0c6c6 f5bde6 c6a0f6 ed8796 ee99a0 f5a97f eed49f a6da95 8bd5ca 91d7e3 7dc4e4 "
        "8aadf4 b7bdf8 cad3f5 b8c0e0 a5adcb 939ab7 8087a2 6e738d 5b6078 494d64 363a4f 24273a "
        "1e2030 181926")),
    "mocha": catppuccin(cp(
        "f5e0dc f2cdcd f5c2e7 cba6f7 f38ba8 eba0ac fab387 f9e2af a6e3a1 94e2d5 89dceb 74c7ec "
        "89b4fa b4befe cdd6f4 bac2de a6adc8 9399b2 7f849c 6c7086 585b70 45475a 313244 1e1e2e "
        "181825 11111b")),
}


# --- Rosé Pine (rose-pine/palette) ---------------------------------------------------------
def rosepine(base, surface, overlay, muted, subtle, text, love, gold, rose, pine, foam, iris,
             hl_low, hl_med, hl_high, light=False, dim=None, lowest=None):
    return build(dict(
        light=light, bg=base, fg=text, sub=subtle, muted=muted,
        dim=dim, lowest=lowest, s1=surface, s2=overlay, s3=hl_med, s4=hl_high,
        red=love, green=pine, yellow=gold, blue=foam, magenta=iris, cyan=rose, orange=gold,
        rose=rose, pink=rose, primary=iris, secondary=foam, tertiary=rose,
        ansi=[overlay, love, pine, gold, foam, iris, rose, text,
              muted, love, pine, gold, foam, iris, rose, text]))


rosepine_ = {
    "dawn": rosepine("faf4ed", "fffaf3", "f2e9e1", "9893a5", "797593", "575279", "b4637a",
                     "ea9d34", "d7827e", "286983", "56949f", "907aa9", "f4ede8", "dfdad9",
                     "cecacd", light=True, dim="f2e9e1", lowest="ebe2da"),
    "main": rosepine("191724", "1f1d2e", "26233a", "6e6a86", "908caa", "e0def4", "eb6f92",
                     "f6c177", "ebbcba", "31748f", "9ccfd8", "c4a7e7", "21202e", "403d52",
                     "524f67", dim="15131f", lowest="110f1a"),
    "moon": rosepine("232136", "2a273f", "393552", "6e6a86", "908caa", "e0def4", "eb6f92",
                     "f6c177", "ea9a97", "3e8fb0", "9ccfd8", "c4a7e7", "2a283e", "44415a",
                     "56526e", dim="1e1c2f", lowest="191727"),
}


# --- One Dark (Atom / navarasu/onedark.nvim) -----------------------------------------------
onedark = {"default": build(dict(
    bg="282C34", fg="ABB2BF", sub="9DA5B4", muted="5C6370",
    dim="21252B", lowest="1B1F23", s1="2C313C", s2="31353F", s3="3E4451", s4="4B5263",
    red="E06C75", green="98C379", yellow="E5C07B", blue="61AFEF", magenta="C678DD",
    cyan="56B6C2", orange="D19A66",
    primary="61AFEF", secondary="98C379", tertiary="C678DD",
    ansi=["282C34", "E06C75", "98C379", "E5C07B", "61AFEF", "C678DD", "56B6C2", "ABB2BF",
          "5C6370", "E06C75", "98C379", "E5C07B", "61AFEF", "C678DD", "56B6C2", "FFFFFF"]))}


# --- Oldworld (dgox16/oldworld.nvim) -------------------------------------------------------
oldworld = {"default": build(dict(
    bg="161617", fg="C9C7CD", sub="B4B1BA", muted="6C6874",
    dim="121213", lowest="0E0E0F", s1="1B1B1C", s2="2A2A2D", s3="313134", s4="3B3B3E",
    red="EA83A5", green="90B99F", yellow="E6B99D", blue="92A2D5", magenta="ACA1CF",
    cyan="85B5BA", orange="F5A191", pink="E29ECA",
    primary="92A2D5", secondary="90B99F", tertiary="E29ECA",
    ansi=["1B1B1C", "EA83A5", "90B99F", "E6B99D", "92A2D5", "E29ECA", "85B5BA", "C9C7CD",
          "6C6874", "EA83A5", "90B99F", "E6B99D", "92A2D5", "E29ECA", "85B5BA", "C9C7CD"]))}


# Darkest flavour first: the Super+T card shows the first one, and apply-colors.sh applies the darkest.
catppuccin_ = {k: catppuccin_[k] for k in ("mocha", "macchiato", "frappe", "latte")}
rosepine_ = {k: rosepine_[k] for k in ("main", "moon", "dawn")}

REBUILT = {"gruvbox": gruvbox, "solarized-osaka": solarized, "gentleman-kanagawa-blur": blur, "catppuccin": catppuccin_, "rosepine": rosepine_,
           "onedark": onedark, "oldworld": oldworld}


def main():
    text = SCHEMES.read_text()
    data = json.loads(text)
    # every rebuilt scheme has the same 110 keys (those of the old hand-made tokyonight scheme)
    keys = list(gruvbox["hard"])
    for name, flavours in REBUILT.items():
        for f, pal in flavours.items():
            assert list(pal) == keys, f"{name}/{f}: keys differ from the reference"
        if name in data:  # only the themes still offered in Super+T; the rest stay here as palettes
            data[name] = flavours
    out = json.dumps(data, indent=2) + "\n"
    if "--check" in sys.argv:
        sys.exit(0 if out == text else 1)
    SCHEMES.write_text(out)


if __name__ == "__main__":
    main()
