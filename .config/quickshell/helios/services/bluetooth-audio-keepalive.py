#!/usr/bin/env python3
"""Keep idle Bluetooth playback ready while a shell interaction is open."""
import ctypes
import json
import signal
import subprocess

NAME = "Helios audio keepalive"


def idle_bluetooth_output(default, sinks, inputs):
    sink = next((s for s in sinks if s["name"] == default), None)
    if not sink or not sink["name"].startswith("bluez_output."):
        return ""
    for stream in inputs:
        props = stream.get("properties", {})
        if stream["sink"] != sink["index"] or stream.get("corked", False):
            continue
        if props.get("application.name") == NAME or props.get("media.name", "").startswith("helios-"):
            continue
        return ""
    return sink["name"]


def stop(process):
    if process and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


def die_with_parent():
    # Quickshell can kill its helper during reload; leave no audio children.
    ctypes.CDLL(None).prctl(1, signal.SIGTERM)


def main():
    player = None
    watcher = None
    target = ""
    def terminate(*_):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, terminate)
    try:
        watcher = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE,
                                   text=True, preexec_fn=die_with_parent)
        def update():
            nonlocal player, target
            default = subprocess.check_output(["pactl", "get-default-sink"], text=True).strip()
            sinks = json.loads(subprocess.check_output(["pactl", "-f", "json", "list", "sinks"]))
            inputs = json.loads(subprocess.check_output(["pactl", "-f", "json", "list", "sink-inputs"]))
            wanted = idle_bluetooth_output(default, sinks, inputs)
            if wanted == target and (not wanted or player.poll() is None):
                return
            stop(player)
            player = None
            target = wanted
            if wanted:
                with open("/dev/zero", "rb") as silence:
                    player = subprocess.Popen([
                        "pw-cat", "--playback", "--raw", "--format", "s16",
                        "--rate", "48000", "--channels", "2", "--latency", "50ms",
                        "--target", wanted, "--properties",
                        'application.name="Helios audio keepalive" media.role=Music '
                        'node.dont-fallback=true node.dont-reconnect=true', "-"
                    ], stdin=silence, preexec_fn=die_with_parent)
        update()
        for event in watcher.stdout:
            if " on sink " in event or " on sink-input " in event or " on server " in event:
                update()
    except (subprocess.SubprocessError, OSError, ValueError) as error:
        print(f"Bluetooth audio keepalive: {error}", flush=True)
    finally:
        stop(player)
        stop(watcher)


if __name__ == "__main__":
    main()
