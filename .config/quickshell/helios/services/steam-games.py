#!/usr/bin/env python3
"""Print installed Steam games (native and Flatpak Steam) as JSON for the Launcher."""
import json
import re
import sys
from pathlib import Path

FLATPAK_ID = "com.valvesoftware.Steam"
# Proton, runtimes and redistributables have app manifests too, but aren't games.
TOOL_NAME = re.compile(r"^(Proton|Steam Linux Runtime|Steamworks Common Redistributables|SteamVR)\b")


def roots(home):
    yield home / ".local/share/Steam", False
    yield home / ".steam/steam", False
    yield home / ".var/app" / FLATPAK_ID / ".local/share/Steam", True
    yield home / ".var/app" / FLATPAK_ID / "data/Steam", True


def vdf_values(text, key):
    return [m.replace("\\\\", "\\") for m in re.findall(r'"%s"\s+"((?:[^"\\]|\\.)*)"' % key, text, re.IGNORECASE)]


def read(path):
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def icon_for(root, appid):
    cache = root / "appcache/librarycache"
    # Current Steam keeps the small icon as the one top-level jpg in <appid>/;
    # older Steam used <appid>_icon.jpg.
    for candidate in sorted((cache / appid).glob("*.jpg")) + [cache / (appid + "_icon.jpg")]:
        if candidate.is_file():
            return str(candidate)
    return ""


def games(home):
    seen_roots, seen_ids, result = set(), set(), []
    for root, flatpak in roots(home):
        try:
            real = root.resolve(strict=True)
        except OSError:
            continue
        if real in seen_roots:
            continue
        seen_roots.add(real)
        libraries = [Path(p) for p in vdf_values(read(real / "steamapps/libraryfolders.vdf"), "path")] or [real]
        for library in dict.fromkeys(libraries):
            for manifest in sorted((library / "steamapps").glob("appmanifest_*.acf")):
                text = read(manifest)
                ids, names = vdf_values(text, "appid"), vdf_values(text, "name")
                if not ids or not names or ids[0] in seen_ids or TOOL_NAME.match(names[0]):
                    continue
                seen_ids.add(ids[0])
                result.append({"appid": ids[0], "name": names[0], "icon": icon_for(real, ids[0]), "flatpak": flatpak})
    return result


if __name__ == "__main__":
    json.dump(games(Path.home()), sys.stdout)
