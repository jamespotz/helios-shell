#!/usr/bin/env python3
# Slow, occasional system-maintenance checks for MaintenanceIsland.qml —
# package updates, pending reboot, firmware updates. Kept out of
# system-info.py's fast poll loop since dnf/fwupd hit the network and can
# take several seconds; services/Maintenance.qml runs this on a long timer.
import json
import subprocess


def _run(cmd, timeout):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, stdin=subprocess.DEVNULL)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None


def dnf_update_count():
    # --assumeno declines any interactive prompt (e.g. importing an untrusted
    # repo GPG key) instead of hanging or silently trusting it.
    result = _run(["dnf", "-q", "--assumeno", "check-update", "--json"], 90)
    if result is None or result.returncode != 0:
        return None
    try:
        return len(json.loads(result.stdout).get("upgrades", []))
    except json.JSONDecodeError:
        return None


def _flatpak_installed_commits():
    # Maps app id -> the set of commits that count as "already installed":
    # its own active commit, plus its alt-id if it has one.
    result = _run(["flatpak", "list", "--columns=application,active,options"], 15)
    if result is None or result.returncode != 0:
        return None
    installed = {}
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        app_id, active, options = parts[0], parts[1], parts[2]
        commits = {active}
        for opt in options.split(","):
            if opt.startswith("alt-id="):
                commits.add(opt.split("=", 1)[1])
        installed[app_id] = commits
    return installed


def flatpak_update_count():
    # `flatpak remote-ls --updates` compares raw commit hashes and doesn't
    # know that Fedora's flatpak remote re-signs the same content under a
    # different commit (exposed on the installed ref as its alt-id) — it's
    # a known flatpak bug (flatpak/flatpak#3748, "ghost updates"). That
    # inflated this to 13 "updates" on a system `flatpak update` itself
    # (and topgrade, which just calls that) correctly saw as fully current.
    # Cross-referencing against alt-id filters those false positives out.
    installed = _flatpak_installed_commits()
    if installed is None:
        return None
    result = _run(["flatpak", "remote-ls", "--updates", "--columns=application,commit"], 30)
    if result is None or result.returncode != 0:
        return None
    count = 0
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        app_id, remote_commit = parts[0], parts[1]
        if remote_commit in installed.get(app_id, set()):
            continue
        count += 1
    return count


def reboot_required():
    result = _run(["dnf", "-q", "--assumeno", "needs-restarting", "--json"], 30)
    if result is None or result.returncode != 0:
        return None
    try:
        entries = json.loads(result.stdout)
        return any(e.get("reboot_required") for e in entries if e.get("type") == "reboot")
    except json.JSONDecodeError:
        return None


def firmware_updates():
    result = _run(["fwupdmgr", "get-updates", "--json"], 30)
    if result is None or result.returncode != 0:
        return []
    try:
        devices = json.loads(result.stdout).get("Devices", [])
    except json.JSONDecodeError:
        return []
    updates = []
    for device in devices:
        releases = device.get("Releases") or []
        if releases:
            updates.append({"name": device.get("Name", "Unknown device"), "version": releases[0].get("Version", "")})
    return updates


if __name__ == "__main__":
    print(json.dumps({
        "dnf_updates": dnf_update_count(),
        "flatpak_updates": flatpak_update_count(),
        "reboot_required": reboot_required(),
        "firmware_updates": firmware_updates(),
    }))
