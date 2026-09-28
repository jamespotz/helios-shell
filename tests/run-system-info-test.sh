#!/usr/bin/env bash

# Runs system-info.py once and checks the snapshot shape the System monitor
# cards bind to. Sensor values vary by machine, so only types are asserted.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

timeout 10s python3 "$repo_root/.config/quickshell/helios/modules/bar/system-info.py" --once | python3 -c '
import json, sys
snapshot = json.loads(sys.stdin.readline())
number = (int, float)
def check(value, types, label):
    if not isinstance(value, types):
        sys.exit(f"SYSTEM_INFO_TEST_FAIL: {label} is {value!r}")
for key in ("system", "user", "idle"):
    check(snapshot["cpu"]["times"][key], number, "cpu.times." + key)
for key in ("cached_gb", "swap_used_gb", "swap_total_gb"):
    check(snapshot["memory"][key], number, "memory." + key)
for key in ("total_gb", "used_gb", "free_gb", "percent"):
    check(snapshot["storage"][key], number, "storage." + key)
check(snapshot["storage"]["mount"], str, "storage.mount")
check(snapshot["sensors"]["cpu_c"], number + (type(None),), "sensors.cpu_c")
check(snapshot["sensors"]["fan_rpm"], number + (type(None),), "sensors.fan_rpm")
for key in ("iface", "iface_type", "local_ip"):
    check(snapshot["network"][key], (str, type(None)), "network." + key)
for process in snapshot["processes"]:
    check(process["memory_mb"], number, "processes[].memory_mb")
print("SYSTEM_INFO_TEST_PASS")
'
