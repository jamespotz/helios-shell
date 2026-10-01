#!/usr/bin/env python3
import psutil
import subprocess
import json
import sys
import time
import os
import signal
import socket
from collections import deque

# --full switches the process snapshot from the dashboard's top-6-by-CPU
# summary to a full (capped) listing for the Process List view — only paid
# for while that view is open, since SystemStats.qml restarts this script
# with/without the flag as the view toggles.
FULL_PROCESS_LIST = "--full" in sys.argv
# --once prints a single snapshot and exits (used by tests).
ONCE = "--once" in sys.argv
FULL_PROCESS_LIMIT = 1000
TOP_PROCESS_LIMIT = 6
# 2s x 60 samples = a two-minute window for SystemMonitorDestination's graphs.
SAMPLE_INTERVAL = 2.0
HISTORY_LENGTH = 60
# Slow-changing values, refreshed less often than the 2s tick.
STORAGE_INTERVAL = 30.0
INTERFACE_INTERVAL = 10.0
# Skipped by the no-default-route fallback: container bridges and VPN tunnels.
VIRTUAL_INTERFACE_PREFIXES = ("lo", "docker", "br-", "veth", "virbr", "tun", "wg", "tailscale", "zt")
_TOTAL_MEMORY = psutil.virtual_memory().total
HISTORY_KEYS = ("cpu", "memory", "gpu", "disk_read_kbs", "disk_write_kbs", "net_sent_kbs", "net_received_kbs")


def act_on_process(pid, action):
    if action not in ("terminate", "forceStop"):
        return {"pid": pid, "success": False, "message": "Unsupported action"}
    if pid == 1:
        return {"pid": pid, "success": False, "message": "Protected process"}
    try:
        process = psutil.Process(pid)
        name = process.name().lower()
        if "quickshell" in name or "hyprland" in name:
            return {"pid": pid, "success": False, "message": "Protected process"}
        os.kill(pid, signal.SIGTERM if action == "terminate" else signal.SIGKILL)
        return {"pid": pid, "success": True, "message": ""}
    except (psutil.NoSuchProcess, ProcessLookupError):
        return {"pid": pid, "success": False, "message": "Process no longer exists"}
    except (psutil.AccessDenied, PermissionError) as error:
        return {"pid": pid, "success": False, "message": str(error)}


def get_gpu():
    try:
        output = subprocess.check_output(
            [
                "nvidia-smi",
                "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu",
                "--format=csv,noheader,nounits",
            ],
            text=True,
        )

        name, usage, mem_used, mem_total, temp = [x.strip() for x in output.split(",")]

        return {
            "name": name,
            "usage_percent": float(usage),
            "memory_used_mb": float(mem_used),
            "memory_total_mb": float(mem_total),
            "temperature_c": float(temp),
        }
    except Exception:
        return None


# psutil computes CPU% as a delta between two calls on the *same* Process
# object. A fresh process_iter() every tick would create new objects and
# always report 0.0%, so keep them cached by PID across iterations — this is
# psutil's documented pattern for exactly this case.
_process_cache = {}
_process_metadata = {}
_gpu_cache = None
_last_gpu_sample = 0.0
# nvidia-smi is a subprocess spawn; every other tick is live enough.
GPU_SAMPLE_INTERVAL = 2 * SAMPLE_INTERVAL


def get_gpu_cached():
    global _gpu_cache, _last_gpu_sample
    now = time.monotonic()
    if _last_gpu_sample == 0.0 or now - _last_gpu_sample >= GPU_SAMPLE_INTERVAL:
        _gpu_cache = get_gpu()
        _last_gpu_sample = now
    return _gpu_cache


def get_processes(limit=6):
    current_pids = set()
    for p in psutil.process_iter(["pid", "name"]):
        pid = p.info["pid"]
        current_pids.add(pid)
        if pid not in _process_cache:
            try:
                p.cpu_percent(interval=None)  # prime the delta tracker
                _process_cache[pid] = p
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue

    for pid in list(_process_cache.keys()):
        if pid not in current_pids:
            del _process_cache[pid]
            _process_metadata.pop(pid, None)

    samples = []
    for pid, p in _process_cache.items():
        try:
            samples.append((p.cpu_percent(interval=None), pid, p))
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    samples.sort(key=lambda sample: sample[0], reverse=True)
    results = []
    for cpu_percent, pid, p in samples[:limit]:
        try:
            metadata = _process_metadata.get(pid)
            if metadata is None:
                with p.oneshot():
                    name = p.name()
                    try:
                        cmdline = " ".join(p.cmdline()) or "[" + name + "]"
                    except (psutil.AccessDenied, psutil.ZombieProcess):
                        cmdline = "[" + name + "]"
                    try:
                        user = p.username()
                    except (psutil.AccessDenied, KeyError):
                        user = ""
                metadata = {"name": name, "cmdline": cmdline, "user": user}
                _process_metadata[pid] = metadata

            rss = p.memory_info().rss
            results.append(
                {
                    "pid": pid,
                    "name": metadata["name"],
                    "cmdline": metadata["cmdline"],
                    "user": metadata["user"],
                    "cpu_percent": cpu_percent,
                    "memory_percent": round(rss / _TOTAL_MEMORY * 100, 1),
                    "memory_mb": round(rss / 1024**2, 1),
                }
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    return results


_slow_cache = {}


def cached(key, interval, compute):
    now = time.monotonic()
    entry = _slow_cache.get(key)
    if entry is None or now - entry[0] >= interval:
        entry = (now, compute())
        _slow_cache[key] = entry
    return entry[1]


def _mount_point(path):
    path = os.path.realpath(path)
    while not os.path.ismount(path):
        path = os.path.dirname(path)
    return path


# The filesystem holding $HOME — the same as / unless /home is its own partition.
def get_storage():
    mount = _mount_point(os.path.expanduser("~"))
    usage = psutil.disk_usage(mount)
    return {
        "mount": mount,
        "total_gb": round(usage.total / 1024**3, 1),
        "used_gb": round(usage.used / 1024**3, 1),
        "free_gb": round(usage.free / 1024**3, 1),
        "percent": usage.percent,
    }


def get_sensors():
    cpu_c = None
    fan_rpm = None
    try:
        temps = psutil.sensors_temperatures()
        # Package/die sensor first; otherwise the chip's first reading.
        for chip, labels in (("coretemp", ("Package id", "Physical id")), ("k10temp", ("Tctl", "Tdie")), ("zenpower", ("Tctl", "Tdie"))):
            entries = temps.get(chip, [])
            match = next((entry for entry in entries if entry.label.startswith(labels)), entries[0] if entries else None)
            if match is not None:
                cpu_c = match.current
                break
    except Exception:
        pass
    try:
        speeds = [fan.current for fans in psutil.sensors_fans().values() for fan in fans if fan.current > 0]
        fan_rpm = max(speeds) if speeds else None
    except Exception:
        pass
    return {"cpu_c": cpu_c, "fan_rpm": fan_rpm}


# Interface of the lowest-metric IPv4 default route, from /proc/net/route.
def _default_route_interface():
    try:
        with open("/proc/net/route") as routes:
            defaults = []
            for line in routes.readlines()[1:]:
                fields = line.split()
                # Destination 0.0.0.0 with the RTF_UP flag set.
                if len(fields) > 6 and fields[1] == "00000000" and int(fields[3], 16) & 1:
                    defaults.append((int(fields[6]), fields[0]))
            return min(defaults)[1] if defaults else None
    except (OSError, ValueError):
        return None


def get_interface():
    stats = psutil.net_if_stats()
    addresses = psutil.net_if_addrs()
    default = _default_route_interface()
    candidates = [default] if default else [
        name for name in addresses if not name.startswith(VIRTUAL_INTERFACE_PREFIXES)
    ]
    for name in candidates:
        if not (name in stats and stats[name].isup):
            continue
        for address in addresses.get(name, []):
            if address.family == socket.AF_INET:
                wireless = os.path.exists(f"/sys/class/net/{name}/wireless")
                return {"iface": name, "iface_type": "wifi" if wireless else "ethernet", "local_ip": address.address}
    return {"iface": None, "iface_type": None, "local_ip": None}


def get_system_stats(network_rate, disk_rate, history, network_counters, disk):
    # Non-blocking: deltas since the previous tick (primed before the loop).
    cpu_usage = psutil.cpu_percent(interval=None)
    per_core = psutil.cpu_percent(interval=None, percpu=True)
    times = psutil.cpu_times_percent(interval=None)
    frequency = psutil.cpu_freq()
    memory = psutil.virtual_memory()
    swap = psutil.swap_memory()
    gpu = get_gpu_cached()
    history["cpu"].append(cpu_usage)
    history["memory"].append(memory.percent)
    # A failed nvidia-smi read records 0 once the graph has started, so the
    # GPU series keeps the same time window as the others.
    if gpu:
        history["gpu"].append(gpu["usage_percent"])
    elif history["gpu"]:
        history["gpu"].append(0)
    snapshot = {
        "cpu": {
            "usage_percent": cpu_usage,
            "per_core": per_core,
            "frequency_mhz": frequency.current if frequency else None,
            "times": {"system": times.system, "user": times.user, "idle": times.idle},
        },
        "memory": {
            "usage_percent": memory.percent,
            "used_gb": round(memory.used / 1024**3, 2),
            "total_gb": round(memory.total / 1024**3, 2),
            "cached_gb": round(getattr(memory, "cached", 0) / 1024**3, 2),
            "swap_used_gb": round(swap.used / 1024**3, 2),
            "swap_total_gb": round(swap.total / 1024**3, 2),
        },
        "storage": cached("storage", STORAGE_INTERVAL, get_storage),
        "sensors": get_sensors(),
        "disk": {
            "read_mb": round(disk.read_bytes / 1024**2, 2),
            "write_mb": round(disk.write_bytes / 1024**2, 2),
        },
        "network": {
            "sent_mb": round(network_counters.bytes_sent / 1024**2, 2),
            "received_mb": round(network_counters.bytes_recv / 1024**2, 2),
            **cached("interface", INTERFACE_INTERVAL, get_interface),
        },
        "gpu": gpu,
        "processes": get_processes(FULL_PROCESS_LIMIT if FULL_PROCESS_LIST else TOP_PROCESS_LIMIT),
    }
    snapshot["network_rate"] = network_rate
    snapshot["disk_rate"] = disk_rate
    snapshot["history"] = {key: list(values) for key, values in history.items()}
    return snapshot


if "--signal" in sys.argv:
    signal_index = sys.argv.index("--signal")
    result = act_on_process(int(sys.argv[signal_index + 1]), sys.argv[signal_index + 2])
    print(json.dumps(result, separators=(",", ":")))
    raise SystemExit(0 if result["success"] else 1)

history = {key: deque(maxlen=HISTORY_LENGTH) for key in HISTORY_KEYS}
last_network = None
last_disk = None
last_sample_time = None
psutil.cpu_percent(interval=None)
psutil.cpu_percent(interval=None, percpu=True)
psutil.cpu_times_percent(interval=None)
time.sleep(0.5)  # so the first sample measures something instead of reading 0%


def _kbs(current, previous, elapsed):
    return max(0, current - previous) / 1024 / elapsed


while True:
    counters = psutil.net_io_counters()
    disk = psutil.disk_io_counters()
    now = time.monotonic()
    network_rate = {"sent_kbs": 0, "received_kbs": 0}
    disk_rate = {"read_kbs": 0, "write_kbs": 0}
    if last_sample_time is not None:
        elapsed = max(now - last_sample_time, 0.001)
        network_rate = {
            "sent_kbs": _kbs(counters.bytes_sent, last_network.bytes_sent, elapsed),
            "received_kbs": _kbs(counters.bytes_recv, last_network.bytes_recv, elapsed),
        }
        disk_rate = {
            "read_kbs": _kbs(disk.read_bytes, last_disk.read_bytes, elapsed),
            "write_kbs": _kbs(disk.write_bytes, last_disk.write_bytes, elapsed),
        }
        history["net_sent_kbs"].append(network_rate["sent_kbs"])
        history["net_received_kbs"].append(network_rate["received_kbs"])
        history["disk_read_kbs"].append(disk_rate["read_kbs"])
        history["disk_write_kbs"].append(disk_rate["write_kbs"])
    last_network = counters
    last_disk = disk
    last_sample_time = now
    print(json.dumps(get_system_stats(network_rate, disk_rate, history, counters, disk), separators=(",", ":")), flush=True)
    if ONCE:
        break
    time.sleep(SAMPLE_INTERVAL)
