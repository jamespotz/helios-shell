#!/usr/bin/env python3
"""Discover removable storage and execute validated UDisks operations."""
import json
import os
import selectors
import signal
import subprocess
import sys
import time

COLUMNS = 'PATH,TYPE,TRAN,RM,SIZE,MODEL,SERIAL,WWN,MAJ:MIN,LABEL,FSTYPE,MOUNTPOINTS'
SYSTEM_PATHS = ('/boot', '/home', '/usr', '/var', '/etc', '/opt', '/srv', '/nix')


def run_command(args):
    return subprocess.run(args, capture_output=True, text=True, timeout=30, check=True).stdout


def descendants(node):
    yield node
    for child in node.get('children', []):
        yield from descendants(child)


def mount_points(node):
    return [point for point in node.get('mountpoints', []) if point]


def is_system_mount(point):
    return point in ('/', '[SWAP]') or any(point == prefix or point.startswith(prefix + '/') for prefix in SYSTEM_PATHS)


def device_identity(disk):
    try:
        node = os.stat(disk['path'])
        node_identity = [node.st_dev, node.st_ino, node.st_rdev, node.st_ctime_ns]
    except OSError:
        node_identity = None
    return [disk.get('serial'), disk.get('wwn'), disk.get('maj:min'), disk.get('size'), disk.get('model'), node_identity]


def discover(run=run_command):
    data = json.loads(run(['lsblk', '--json', '--bytes', '--paths', '--tree', '--output', COLUMNS]))
    result = []
    for disk in data.get('blockdevices', []):
        if disk.get('type') != 'disk' or not (disk.get('tran') == 'usb' or disk.get('rm') in (True, 1)):
            continue
        nodes = list(descendants(disk))
        if any(is_system_mount(point) for node in nodes for point in mount_points(node)):
            continue
        partitions = []
        for node in nodes:
            if node is disk and not node.get('fstype'):
                continue
            filesystem = node.get('fstype') or ''
            partitions.append({
                'path': node['path'], 'label': node.get('label') or os.path.basename(node['path']),
                'sizeBytes': int(node.get('size') or 0), 'filesystem': filesystem,
                'mountPoints': mount_points(node),
                'supported': bool(filesystem) and filesystem not in ('crypto_LUKS', 'swap', 'LVM2_member', 'linux_raid_member'),
            })
        result.append({'path': disk['path'], 'label': (disk.get('model') or disk.get('label') or os.path.basename(disk['path'])).strip(),
                       'sizeBytes': int(disk.get('size') or 0), 'identity': device_identity(disk), 'partitions': partitions})
    return result


def error_text(error):
    detail = getattr(error, 'stderr', None)
    return detail.strip() if isinstance(detail, str) and detail.strip() else str(error)


def operate(action, path, run=run_command):
    try:
        current = discover(run)
        disk = next((disk for disk in current if disk['path'] == path), None)
        partition = next((part for disk in current for part in disk['partitions'] if part['path'] == path), None)
        if action == 'eject':
            if disk is None:
                raise ValueError('Drive is unavailable or is not removable storage')
            for part in disk['partitions']:
                if part['mountPoints']:
                    run(['udisksctl', 'unmount', '--block-device', part['path']])
            # Recheck mounts after unmount: a new mount or changed target stops power-off.
            refreshed = next((item for item in discover(run) if item['path'] == path), None)
            if refreshed is None:
                raise ValueError('Drive disappeared before eject')
            if refreshed['identity'] != disk['identity']:
                raise ValueError('Drive changed before eject; refresh and try again')
            if any(part['mountPoints'] for part in refreshed['partitions']):
                raise ValueError('Drive still has mounted filesystems')
            # UDisks power-off itself rejects mounted/busy filesystems. Never force it.
            run(['udisksctl', 'power-off', '--block-device', path])
        elif action in ('mount', 'unmount', 'open'):
            if partition is None or not partition['supported']:
                raise ValueError('Filesystem is unavailable or unsupported')
            if action == 'open':
                if not partition['mountPoints']:
                    raise ValueError('Mount the filesystem before opening it')
                run(['xdg-open', partition['mountPoints'][0]])
            elif action == 'mount':
                if partition['mountPoints']:
                    raise ValueError('Filesystem is already mounted')
                run(['udisksctl', 'mount', '--block-device', path])
            else:
                if not partition['mountPoints']:
                    raise ValueError('Filesystem is not mounted')
                run(['udisksctl', 'unmount', '--block-device', path])
        else:
            raise ValueError('Unknown drive action')
        return {'ok': True, 'drives': discover(run), 'error': ''}
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        return {'ok': False, 'error': error_text(error)}


def snapshot():
    try:
        return {'ok': True, 'drives': discover(), 'error': ''}
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        return {'ok': False, 'error': error_text(error)}


def emit(result):
    print(json.dumps(result), flush=True)


def watch():
    monitor = None
    def stop(signum, frame):
        raise SystemExit(0)
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        monitor = subprocess.Popen(['udisksctl', 'monitor'], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        emit(snapshot())
        with selectors.DefaultSelector() as selector:
            selector.register(monitor.stdout, selectors.EVENT_READ)
            deadline = None
            while True:
                timeout = max(0, deadline - time.monotonic()) if deadline else None
                events = selector.select(timeout)
                if events:
                    chunk = os.read(monitor.stdout.fileno(), 65536)
                    if not chunk:
                        emit({'ok': False, 'error': 'UDisks device monitor stopped'})
                        return 1
                    deadline = time.monotonic() + 0.2
                elif deadline is not None:
                    emit(snapshot())
                    deadline = None
    except OSError as error:
        emit({'ok': False, 'error': error_text(error)})
        return 1
    finally:
        if monitor is not None:
            monitor.terminate()
            try:
                monitor.wait(timeout=2)
            except subprocess.TimeoutExpired:
                monitor.kill()
                monitor.wait()


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'list'
    if action == 'watch':
        return watch()
    result = snapshot() if action == 'list' else operate(action, sys.argv[2] if len(sys.argv) > 2 else '')
    emit(result)
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    sys.exit(main())
