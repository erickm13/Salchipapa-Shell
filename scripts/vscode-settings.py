#!/usr/bin/env python3
"""Merge a theme's VS Code settings into the user's settings.json (VS Code reloads it live).

Usage: vscode-settings.py apply <theme vscode.json> <state dir>
       vscode-settings.py restore <state dir>

apply: the first time, saves the user's own workbench.colorTheme in <state>/vscode-previous.json;
then sets the theme's keys (workbench.colorCustomizations and editor.tokenColorCustomizations are
merged per key, so the user's other customizations stay). restore: puts the saved workbench.colorTheme back (theme without vscode.json).
settings.json is JSONC: trailing commas are accepted; with comments it is left untouched.
"""
import json
import re
import sys
from pathlib import Path

SETTINGS = Path.home() / ".config/Code/User/settings.json"


def load():
    raw = SETTINGS.read_text()
    if re.search(r'^\s*//|/\*', raw, re.M):
        sys.exit("vscode-settings: settings.json tiene comentarios; no se toca")
    return json.loads(re.sub(r',(\s*[}\]])', r'\1', raw))


def save(data):
    SETTINGS.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")


def main():
    if not SETTINGS.exists():
        return
    mode = sys.argv[1]
    data = load()
    prev = Path(sys.argv[3 if mode == "apply" else 2]) / "vscode-previous.json"
    if mode == "apply":
        theme = json.loads(Path(sys.argv[2]).read_text())
        if not prev.exists():
            prev.write_text(json.dumps({"workbench.colorTheme": data.get("workbench.colorTheme")}) + "\n")
        for key, value in theme.items():
            if key in ("workbench.colorCustomizations", "editor.tokenColorCustomizations"):
                data.setdefault(key, {}).update(value)
            else:
                data[key] = value
    elif mode == "restore":
        if not prev.exists():
            return
        old = json.loads(prev.read_text()).get("workbench.colorTheme")
        if old:
            data["workbench.colorTheme"] = old
        else:
            data.pop("workbench.colorTheme", None)
        prev.unlink()
    save(data)


if __name__ == "__main__":
    main()
