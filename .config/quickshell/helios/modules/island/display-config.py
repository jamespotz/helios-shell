#!/usr/bin/env python3
import os
import re
import argparse
import sys
import glob
import subprocess
import json
from pathlib import Path

def get_default_config_path():
    xdg_config = os.environ.get("XDG_CONFIG_HOME")
    if xdg_config:
        return Path(xdg_config) / "hypr" / "hyprland.lua"
    return Path.home() / ".config" / "hypr" / "hyprland.lua"

def resolve_require_paths(base_dir, require_string):
    clean_req = require_string.strip("'\"")
    if "*" in clean_req:
        search_path = os.path.join(base_dir, clean_req)
        matched_paths = []
        for p in glob.glob(search_path):
            path_obj = Path(p)
            if path_obj.is_file() and path_obj.suffix == '.lua':
                matched_paths.append(path_obj.resolve())
            elif path_obj.is_dir():
                matched_paths.extend([f.resolve() for f in path_obj.glob("*.lua")])
        return matched_paths

    if "/" not in clean_req and "." in clean_req:
        path_str = clean_req.replace(".", "/")
    else:
        path_str = clean_req

    possible_file = (base_dir / f"{path_str}.lua").resolve()
    if possible_file.exists():
        return [possible_file]
    return []

def scan_and_collect_files(entry_file, visited=None):
    if visited is None:
        visited = set()
    entry_path = Path(entry_file).resolve()
    if entry_path in visited or not entry_path.exists():
        return visited
    visited.add(entry_path)
    try:
        content = entry_path.read_text()
    except Exception:
        return visited
    # Follows both require(...) and utils.safe_load(...) — this repo's
    # hyprland.lua loads most modules via the latter (dofile under the
    # hood), so require-only traversal would miss them entirely.
    require_pattern = re.compile(
        r'require\s*\(\s*([^)]+)\s*\)|require\s+([\'"][^\'"]+[\'"])'
        r'|utils\.safe_load\s*\(\s*([^)]+)\s*\)'
    )
    base_dir = entry_path.parent
    for match in require_pattern.findall(content):
        require_str = next((g for g in match if g), None)
        if not require_str:
            continue
        for file in resolve_require_paths(base_dir, require_str):
            scan_and_collect_files(file, visited)
    return visited

def update_monitor_in_file(file_path, target_output, mode=None, position=None, scale=None, vrr=None, transform=None, cm=None, bitdepth=None):
    content = file_path.read_text()
    monitor_pattern = re.compile(r'(hl\.monitor\s*\(\s*\{[^{}]*\}\s*\))', re.DOTALL)
    matches = monitor_pattern.findall(content)
    if not matches:
        return False

    updated = False
    new_content = content

    for block in matches:
        output_match = re.search(r'output\s*=\s*["\']' + re.escape(target_output) + r'["\']', block)
        if output_match:
            updated_block = block

            def update_key(block_str, key, value):
                formatted_val = f'"{value}"' if isinstance(value, str) and value != "auto" else value
                key_pattern = re.compile(r'(' + key + r'\s*=\s*)([^,}\n]+)')
                if key_pattern.search(block_str):
                    # A plain "\1<value>" replacement string breaks when
                    # <value> starts with a digit (e.g. scale "1.5") — regex
                    # reads "\1" followed by "1" as backreference group 11,
                    # not group 1 followed by literal text. A callable
                    # replacement sidesteps backreference parsing entirely.
                    return key_pattern.sub(lambda m: m.group(1) + str(formatted_val), block_str)
                else:
                    # The block's last field already ends in a trailing
                    # comma before "})" — appending ",\n    key = val" after
                    # it as-is would leave a double comma. Strip that
                    # trailing ",})" (or "})" with no comma) first, then
                    # rebuild it cleanly.
                    stripped = re.sub(r',?\s*\}\s*\)\s*$', '', block_str)
                    return stripped + f',\n    {key} = {formatted_val}\n}})'

            if mode:
                updated_block = update_key(updated_block, "mode", mode)
            if position:
                updated_block = update_key(updated_block, "position", position)
            if scale:
                try:
                    scale_val = float(scale) if '.' in scale else int(scale)
                except ValueError:
                    scale_val = scale
                updated_block = update_key(updated_block, "scale", scale_val)
            if vrr is not None:
                updated_block = update_key(updated_block, "vrr", int(vrr))
            if transform is not None:
                updated_block = update_key(updated_block, "transform", int(transform))
            if cm is not None:
                updated_block = update_key(updated_block, "cm", cm)
            if bitdepth is not None:
                updated_block = update_key(updated_block, "bitdepth", int(bitdepth))

            new_content = new_content.replace(block, updated_block)
            updated = True
            break

    if updated:
        file_path.write_text(new_content)
        return True
    return False

def _hyprctl_monitors():
    res = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True)
    # Handle dirty JSON line output edge-cases some Hyprland builds produce
    clean_stdout = res.stdout
    if clean_stdout.strip().startswith("adding monitors"):
        clean_stdout = clean_stdout.replace("adding monitors", "", 1)
    return json.loads(clean_stdout)

def validate_scale(target_output, scale):
    if not 1 <= scale <= 2:
        raise ValueError("Scale must be between 1 and 2.")
    monitor = next((item for item in _hyprctl_monitors() if item.get("name") == target_output), None)
    if monitor is None:
        raise ValueError(f"Monitor '{target_output}' is not currently connected.")
    logical_width = monitor.get("width", 0) / scale
    logical_height = monitor.get("height", 0) / scale
    if not (logical_width.is_integer() and logical_height.is_integer()):
        raise ValueError(
            f"Scale {scale:g} produces non-integer logical size "
            f"{logical_width:g}x{logical_height:g}."
        )

def configured_monitor_values(entry_config):
    values = {}
    monitor_pattern = re.compile(r'hl\.monitor\s*\(\s*\{([^{}]*)\}\s*\)', re.DOTALL)
    for config_file in scan_and_collect_files(entry_config):
        for block in monitor_pattern.findall(config_file.read_text()):
            output_match = re.search(r'output\s*=\s*["\']([^"\']+)["\']', block)
            if not output_match:
                continue
            monitor_values = {}
            for key in ("vrr", "cm", "bitdepth"):
                value_match = re.search(r'\b' + key + r'\s*=\s*([^,}\n]+)', block)
                if value_match:
                    monitor_values[key] = value_match.group(1).strip().strip('"\'')
            values[output_match.group(1)] = monitor_values
    return values

def query_monitor_system(target_output, entry_config, as_json=False, all_monitors=False):
    """Queries hyprctl to collect current configuration parameters, specs, and supported modes."""
    try:
        monitors_data = _hyprctl_monitors()
    except Exception as e:
        print(f"Error querying Hyprland session via hyprctl: {e}", file=sys.stderr)
        sys.exit(1)

    configured = configured_monitor_values(entry_config) if entry_config.exists() else {}
    for item in monitors_data:
        item_config = configured.get(item.get("name"), {})
        item["vrrMode"] = int(item_config.get("vrr", 0))
        item["colorManagementPreset"] = item_config.get(
            "cm", item.get("colorManagementPreset", "srgb")
        )
        if "bitdepth" in item_config:
            item["configuredBitdepth"] = int(item_config["bitdepth"])

    if all_monitors:
        print(json.dumps(monitors_data))
        return

    monitor = next((m for m in monitors_data if m.get("name") == target_output), None)
    if not monitor:
        print(f"Error: Monitor '{target_output}' is not currently connected to the system.", file=sys.stderr)
        if not as_json:
            print("Connected monitors: " + ", ".join([m.get("name") for m in monitors_data]))
        sys.exit(1)

    modes = sorted(set(monitor.get("availableModes", [])))

    if as_json:
        print(json.dumps({
            "output": target_output,
            "width": monitor.get("width"),
            "height": monitor.get("height"),
            "refreshRate": monitor.get("refreshRate"),
            "x": monitor.get("x"),
            "y": monitor.get("y"),
            "scale": monitor.get("scale"),
            "vrr": monitor.get("vrr"),
            "vrrMode": monitor.get("vrrMode", 0),
            "colorManagementPreset": monitor.get("colorManagementPreset", "srgb"),
            "focused": monitor.get("focused"),
            "availableModes": modes,
        }))
        return

    print(f"\n=== System Profile for Monitor: {target_output} ===")
    print(f"  Current Resolution : {monitor.get('width')}x{monitor.get('height')} @ {monitor.get('refreshRate'):.2f}Hz")
    print(f"  Current Layout Position : {monitor.get('x')}x{monitor.get('y')}")
    print(f"  Current UI Scaling : {monitor.get('scale')}")
    print(f"  Current VRR State  : {monitor.get('vrr', 'N/A')}")
    print(f"  Focused Display    : {'Yes' if monitor.get('focused') else 'No'}")

    if modes:
        print("\n[Available Resolution Modes]")
        for mode in modes:
            print(f"  - {mode}")
    else:
        print("\n[Available Resolution Modes]: No structural modelines reported via hyprctl.")

    print("\n[Suggested Scale Values]")
    print("  - 1.00 (Standard DPI)")
    print("  - 1.25 (Compact HiDPI)")
    print("  - 1.50 (Balanced HiDPI)")
    print("  - 2.00 (Integer Retina Display scaling)")

def main():
    parser = argparse.ArgumentParser(
        description="Update or Query monitor specs across a modular Hyprland Lua ecosystem."
    )
    parser.add_argument("-o", "--output", help="Monitor output identifier (e.g., 'DP-1')")
    parser.add_argument("-m", "--mode", help="Resolution/Refresh rate configuration string")
    parser.add_argument("-p", "--pos", help="Layout screen mapping placement array index coordinate")
    parser.add_argument("-s", "--scale", help="UI layout scale element")
    parser.add_argument("-v", "--vrr", type=int, choices=[-1, 0, 1, 2, 3],
                        help="Variable Refresh Rate value (-1: global, 0: off, 1: on, 2: fullscreen, 3: video/game content)")
    parser.add_argument("-t", "--transform", type=int, choices=range(0, 8), help="Output transform/rotation (0-7)")
    parser.add_argument("--cm", choices=["auto", "srgb", "dcip3", "dp3", "adobe", "wide", "edid", "hdr", "hdredid"],
                        help="Color management preset")
    parser.add_argument("--bitdepth", type=int, choices=[8, 10], help="Output color bit depth")
    parser.add_argument("-q", "--query", action="store_true", help="Query and inspect system display attributes")
    parser.add_argument("--json", action="store_true", help="With --query, print machine-readable JSON instead of a text report")
    parser.add_argument("--all", action="store_true", help="With --query and --json, return all connected monitors")
    parser.add_argument("-c", "--config", help="Custom entry point location overrides path")

    args = parser.parse_args()

    entry_config = Path(args.config) if args.config else get_default_config_path()

    if not args.all and not args.output:
        parser.error("--output is required unless --all is used")
    if args.all and (not args.query or not args.json):
        parser.error("--all requires --query and --json")

    if args.query:
        query_monitor_system(args.output, entry_config, as_json=args.json, all_monitors=args.all)
        sys.exit(0)

    # Mutation Guard Enforcement
    if not any([args.mode, args.pos, args.scale, args.vrr is not None, args.transform is not None,
                args.cm is not None, args.bitdepth is not None]):
        print("Error: Provide at least one element property adjustment key, or use --query flag.", file=sys.stderr)
        sys.exit(1)

    if args.scale is not None:
        try:
            validate_scale(args.output, float(args.scale))
        except (ValueError, subprocess.SubprocessError, json.JSONDecodeError) as error:
            print(f"Error: {error}", file=sys.stderr)
            sys.exit(1)

    if not entry_config.exists():
        print(f"Error: Main config file structure missing: {entry_config}", file=sys.stderr)
        sys.exit(1)

    print(f"Traversing modular configuration graph starting at: {entry_config}")
    all_config_files = scan_and_collect_files(entry_config)

    success = False
    for config_file in all_config_files:
        if update_monitor_in_file(config_file, args.output, args.mode, args.pos, args.scale,
                                  args.vrr, args.transform, args.cm, args.bitdepth):
            print(f"--> Success! Patched '{args.output}' entry structural definition inside: {config_file}")

            # Instantly apply updates to active workspace workspace layer configurations
            print("Refreshing Hyprland live state...")
            subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL)
            success = True
            break

    if not success:
        print(f"Error: Monitor entity '{args.output}' not initialized within parsed configuration map.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
