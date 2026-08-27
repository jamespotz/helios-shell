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
    }


while True:
    print(json.dumps(get_system_stats(), indent=2))
    time.sleep(5)
