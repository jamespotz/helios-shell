#!/usr/bin/env python3
"""Keep idle Bluetooth playback ready while a shell interaction is open."""
import ctypes
import json
import os
import select
import signal
import subprocess
import time

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


def event_batches(stream):
    # Coalesce event bursts from slider drags. Wait only after an event;
    # there is no timer or polling while audio state is unchanged.
    pending = b""
    while True:
        data = os.read(stream.fileno(), 65536)
        if not data:
            return
        pending += data
        deadline = time.monotonic() + 0.05
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([stream], [], [], remaining)[0]:
                break
            data = os.read(stream.fileno(), 65536)
            if not data:
                break
            pending += data
        lines = pending.split(b"\n")
        pending = lines.pop()
        if lines:
            yield [line.decode() for line in lines]


def main():
    player = None
    watcher = None
    target = ""
    default = ""
    sinks = []
    def terminate(*_):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, terminate)
    try:
        watcher = subprocess.Popen(["pactl", "subscribe"], stdout=subprocess.PIPE,
                                   preexec_fn=die_with_parent)
        def update(refresh_outputs=False):
            nonlocal player, target, default, sinks
            if refresh_outputs:
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
        update(True)
        for events in event_batches(watcher.stdout):
            # Sink volume changes cannot affect the keepalive target. Refresh
            # outputs only when devices appear/disappear or routing changes.
            refresh_outputs = any(" on server " in event or
                (" on sink " in event and "'change'" not in event) for event in events)
            if refresh_outputs or any(" on sink-input " in event for event in events):
                update(refresh_outputs)
    except (subprocess.SubprocessError, OSError, ValueError) as error:
        print(f"Bluetooth audio keepalive: {error}", flush=True)
    finally:
        stop(player)
        stop(watcher)


if __name__ == "__main__":
    main()
