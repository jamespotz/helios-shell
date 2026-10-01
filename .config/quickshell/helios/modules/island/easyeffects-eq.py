#!/usr/bin/env python3
# Bridges MediaCard.qml's equalizer widget to a real EasyEffects output
# preset. EasyEffects 8.x has no live per-band-gain API (its CLI only does
# whole-preset load/bypass), so this works by reading whatever preset is
# currently active (to keep its loudness/maximizer/etc. untouched), swapping
# in new band gains, writing the result out as a preset file, and loading
# that with `--load-preset` — the one thing EasyEffects does support.
#
# Two modes:
#   --ensure-presets              create the 8 named presets MediaCard.qml's
#                                  buttons load, if they don't exist yet
#                                  (never overwrites a user's own edits)
#   <10 gains in dB>               merge into the live base preset, save as
#                                  "_HeliosLive", and load it — called on
#                                  slider release, not during drag (each
#                                  call shells out to `flatpak run`)
import json
import os
import subprocess
import sys

PRESET_DIR = os.path.expanduser("~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output")
DB_FILE = os.path.expanduser("~/.var/app/com.github.wwmm.easyeffects/config/easyeffects/db/easyeffectsrc")
LIVE_NAME = "_HeliosLive"
FREQS = [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

# Same curves as MediaCard.qml's eqPresets (0..1 slider units), converted to
# dB the same way the QML side converts a drag: (v - 0.5) * 24.
STATIC_PRESETS = {
    "Flat":    [0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50, 0.50],
    "Bass":    [0.90, 0.85, 0.75, 0.65, 0.55, 0.45, 0.40, 0.35, 0.30, 0.30],
    "Pop":     [0.40, 0.45, 0.55, 0.65, 0.70, 0.65, 0.55, 0.50, 0.50, 0.55],
    "Rock":    [0.70, 0.65, 0.50, 0.40, 0.45, 0.55, 0.65, 0.70, 0.70, 0.65],
    "Treble":  [0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.75, 0.85, 0.90, 0.90],
    "Vocal":   [0.35, 0.40, 0.50, 0.65, 0.75, 0.75, 0.65, 0.50, 0.45, 0.40],
    "Jazz":    [0.55, 0.50, 0.45, 0.50, 0.60, 0.60, 0.50, 0.45, 0.50, 0.55],
    "Classic": [0.50, 0.50, 0.50, 0.55, 0.55, 0.50, 0.50, 0.50, 0.55, 0.60],
}


def slider_to_db(v):
    return (v - 0.5) * 24.0


def load_last_output_preset_name():
    if not os.path.exists(DB_FILE):
        return None
    with open(DB_FILE) as f:
        for line in f:
            if line.startswith("lastLoadedOutputPreset="):
                return line.strip().split("=", 1)[1]
    return None


def load_json(name):
    path = os.path.join(PRESET_DIR, name + ".json")
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return None


def merge_bands(data, gains_db):
    eq = data["output"]["equalizer#0"]
    eq["bypass"] = False
    eq["num-bands"] = 10
    for ch in ("left", "right"):
        for i, (freq, gain) in enumerate(zip(FREQS, gains_db)):
            band = eq[ch].setdefault(f"band{i}", {})
            band["frequency"] = float(freq)
            band["gain"] = float(gain)
            band.setdefault("mode", "APO (DR)")
            band.setdefault("mute", False)
            band.setdefault("q", 1.0)
            band.setdefault("slope", "x1")
            band.setdefault("solo", False)
            band.setdefault("type", "Bell")
            band.setdefault("width", 4.0)
    return data


def load_preset(name):
    subprocess.run(
        ["flatpak", "run", "com.github.wwmm.easyeffects", "--load-preset", name],
        check=False,
    )


def ensure_presets():
    os.makedirs(PRESET_DIR, exist_ok=True)
    base = load_json("BuiltIn") or {"output": {
        "blocklist": [], "loudness#0": {}, "maximizer#0": {},
        "plugins_order": ["equalizer#0", "loudness#0", "maximizer#0"],
        "equalizer#0": {"balance": 0.0, "bypass": False, "input-gain": 0.0,
                         "left": {}, "right": {}, "mode": "IIR",
                         "num-bands": 10, "output-gain": 0.0,
                         "pitch-left": 0.0, "pitch-right": 0.0,
                         "split-channels": False},
    }}
    for name, values in STATIC_PRESETS.items():
        path = os.path.join(PRESET_DIR, name + ".json")
        if os.path.exists(path):
            continue
        data = json.loads(json.dumps(base))  # deep copy
        merge_bands(data, [slider_to_db(v) for v in values])
        with open(path, "w") as f:
            json.dump(data, f, indent=4)


def apply_live(gains_db):
    base_name = load_last_output_preset_name()
    data = None
    for name in (base_name, LIVE_NAME, "BuiltIn"):
        if name:
            data = load_json(name)
            if data:
                break
    if data is None:
        sys.exit("easyeffects-eq.py: no base preset found (is EasyEffects set up at all?)")
    merge_bands(data, gains_db)
    os.makedirs(PRESET_DIR, exist_ok=True)
    with open(os.path.join(PRESET_DIR, LIVE_NAME + ".json"), "w") as f:
        json.dump(data, f, indent=4)
    load_preset(LIVE_NAME)


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--ensure-presets":
        ensure_presets()
        return
    if len(sys.argv) == 11:
        apply_live([float(g) for g in sys.argv[1:]])
        return
    sys.exit("usage: easyeffects-eq.py --ensure-presets | <10 band gains in dB>")


if __name__ == "__main__":
    main()
