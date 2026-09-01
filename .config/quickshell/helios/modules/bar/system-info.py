#!/usr/bin/env python3
import psutil
import subprocess
import json
import sys
import time
import os
import signal
from collections import deque

# --full switches the process snapshot from the dashboard's top-6-by-CPU
# summary to a full (capped) listing for the Process List view — only paid
# for while that view is open, since SystemStats.qml restarts this script
# with/without the flag as the view toggles.
FULL_PROCESS_LIST = "--full" in sys.argv
FULL_PROCESS_LIMIT = 1000
TOP_PROCESS_LIMIT = 6
HISTORY_LENGTH = 30


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
# object. A fresh process_iter() every 5s tick would create new objects and
# always report 0.0%, so keep them cached by PID across iterations — this is
# psutil's documented pattern for exactly this case.
_process_cache = {}


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

    results = []
    for pid, p in _process_cache.items():
        try:
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
                results.append(
                    {
                        "pid": pid,
                        "name": name,
                        "cmdline": cmdline,
                        "user": user,
                        "cpu_percent": p.cpu_percent(interval=None),
                        "memory_percent": round(p.memory_percent(), 1),
                    }
                )
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue

    results.sort(key=lambda r: r["cpu_percent"], reverse=True)
    return results[:limit]


def get_system_stats(rate, sent_history, received_history):
    snapshot = {
        "cpu": {
            "usage_percent": psutil.cpu_percent(interval=0.5),
            "per_core": psutil.cpu_percent(percpu=True),
            "frequency_mhz": psutil.cpu_freq().current if psutil.cpu_freq() else None,
        },
        "memory": {
            "usage_percent": psutil.virtual_memory().percent,
            "used_gb": round(psutil.virtual_memory().used / 1024**3, 2),
            "total_gb": round(psutil.virtual_memory().total / 1024**3, 2),
        },
        "disk": {
            "read_mb": round(psutil.disk_io_counters().read_bytes / 1024**2, 2),
            "write_mb": round(psutil.disk_io_counters().write_bytes / 1024**2, 2),
        },
        "network": {
            "sent_mb": round(psutil.net_io_counters().bytes_sent / 1024**2, 2),
            "received_mb": round(psutil.net_io_counters().bytes_recv / 1024**2, 2),
        },
        "gpu": get_gpu(),
        "processes": get_processes(FULL_PROCESS_LIMIT if FULL_PROCESS_LIST else TOP_PROCESS_LIMIT),
    }
    snapshot["network_rate"] = rate
    snapshot["network_history"] = {
        "sent_kbs": list(sent_history),
        "received_kbs": list(received_history),
    }
    return snapshot


if "--signal" in sys.argv:
    signal_index = sys.argv.index("--signal")
    result = act_on_process(int(sys.argv[signal_index + 1]), sys.argv[signal_index + 2])
    print(json.dumps(result, separators=(",", ":")))
    raise SystemExit(0 if result["success"] else 1)

sent_history = deque(maxlen=HISTORY_LENGTH)
received_history = deque(maxlen=HISTORY_LENGTH)
last_network = None
last_sample_time = None

while True:
    counters = psutil.net_io_counters()
    now = time.monotonic()
    rate = {"sent_kbs": 0, "received_kbs": 0}
    if last_network is not None and last_sample_time is not None:
        elapsed = max(now - last_sample_time, 0.001)
        rate = {
            "sent_kbs": max(0, counters.bytes_sent - last_network.bytes_sent) / 1024 / elapsed,
            "received_kbs": max(0, counters.bytes_recv - last_network.bytes_recv) / 1024 / elapsed,
        }
        sent_history.append(rate["sent_kbs"])
        received_history.append(rate["received_kbs"])
    last_network = counters
    last_sample_time = now
    print(json.dumps(get_system_stats(rate, sent_history, received_history), separators=(",", ":")), flush=True)
    time.sleep(5)
