#!/usr/bin/env python3
import psutil
import subprocess
import json
import time


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
            results.append(
                {
                    "pid": pid,
                    "name": p.name(),
                    "cpu_percent": p.cpu_percent(interval=None),
                    "memory_percent": round(p.memory_percent(), 1),
                }
            )
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue

    results.sort(key=lambda r: r["cpu_percent"], reverse=True)
    return results[:limit]


def get_system_stats():
    return {
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
        "processes": get_processes(),
    }


while True:
    print(json.dumps(get_system_stats(), indent=2))
    time.sleep(5)
