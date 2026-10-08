import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

HELPER = Path(__file__).resolve().parents[2] / '.config/quickshell/helios/modules/island/removable-drives.py'
spec = importlib.util.spec_from_file_location('removable_drives', HELPER)
drives = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drives)


def partition(path, mounts=None, fs='ext4'):
    return {'path': path, 'type': 'part', 'size': 1024, 'fstype': fs, 'label': "Disk ' label", 'mountpoints': mounts or [None]}


def disk(path='/dev/sdz', transport='usb', removable=False, children=None):
    return {'path': path, 'type': 'disk', 'tran': transport, 'rm': removable, 'size': 4096, 'model': 'USB drive', 'serial': 'original', 'wwn': '', 'maj:min': '8:240', 'mountpoints': [None], 'children': children or [partition(path + '1')]}


class Runner:
    def __init__(self, devices, fail=None):
        self.devices = devices
        self.fail = fail
        self.calls = []

    def __call__(self, args):
        self.calls.append(args)
        if args[0] == 'lsblk':
            return json.dumps({'blockdevices': self.devices})
        if self.fail and self.fail in args:
            raise subprocess.CalledProcessError(1, args, stderr='filesystem busy')
        if args[0] == 'udisksctl' and args[1] == 'unmount':
            for disk in self.devices:
                for part in disk.get('children', []):
                    if part['path'] == args[-1]:
                        part['mountpoints'] = [None]
        return ''


class DrivesTest(unittest.TestCase):
    def test_includes_usb_without_removable_flag_excludes_internal_and_system(self):
        run = Runner([disk(), disk('/dev/nvme0n1', 'nvme'), disk('/dev/sda', 'usb', children=[partition('/dev/sda1', ['/'])]), disk('/dev/sdb', 'usb', children=[partition('/dev/sdb1', ['/home/user'])])])
        result = drives.discover(run)
        self.assertEqual([d['path'] for d in result], ['/dev/sdz'])
        self.assertEqual(result[0]['partitions'][0]['label'], "Disk ' label")

    def test_encrypted_and_missing_filesystem_unsupported(self):
        run = Runner([disk(children=[partition('/dev/sdz1', fs='crypto_LUKS'), partition('/dev/sdz2', fs=None)])])
        self.assertEqual([p['supported'] for p in drives.discover(run)[0]['partitions']], [False, False])
        self.assertFalse(drives.operate('mount', '/dev/sdz1', run)['ok'])

    def test_eject_unmounts_every_partition_before_power_off(self):
        run = Runner([disk(children=[partition('/dev/sdz1', ['/run/media/me/a']), partition('/dev/sdz2', ['/run/media/me/b'])])])
        self.assertTrue(drives.operate('eject', '/dev/sdz', run)['ok'])
        actions = [args for args in run.calls if args[0] == 'udisksctl']
        self.assertEqual(actions, [['udisksctl', 'unmount', '--block-device', '/dev/sdz1'], ['udisksctl', 'unmount', '--block-device', '/dev/sdz2'], ['udisksctl', 'power-off', '--block-device', '/dev/sdz']])

    def test_busy_partition_prevents_power_off(self):
        run = Runner([disk(children=[partition('/dev/sdz1', ['/run/media/me/a'])])], fail='unmount')
        result = drives.operate('eject', '/dev/sdz', run)
        self.assertFalse(result['ok'])
        self.assertIn('busy', result['error'])
        self.assertFalse(any('power-off' in args for args in run.calls))

    def test_rejects_stale_and_internal_paths(self):
        for devices in ([], [disk('/dev/sdz', 'sata')]):
            run = Runner(devices)
            self.assertFalse(drives.operate('eject', '/dev/sdz', run)['ok'])
            self.assertFalse(any(args[0] == 'udisksctl' for args in run.calls))

    def test_mount_failure_and_unsupported_power_off_visible(self):
        for action, path in [('mount', '/dev/sdz1'), ('eject', '/dev/sdz')]:
            result = drives.operate(action, path, Runner([disk()], fail='mount' if action == 'mount' else 'power-off'))
            self.assertFalse(result['ok'])
            self.assertTrue(result['error'])

    def test_remounted_partition_prevents_power_off(self):
        base = Runner([disk(children=[partition('/dev/sdz1', ['/run/media/me/a'])])])
        def remount(args):
            result = base(args)
            if args[0] == 'udisksctl' and args[1] == 'unmount':
                base.devices[0]['children'][0]['mountpoints'] = ['/run/media/me/a']
            return result
        self.assertFalse(drives.operate('eject', '/dev/sdz', remount)['ok'])
        self.assertFalse(any('power-off' in args for args in base.calls))

    def test_replaced_drive_is_not_powered_off(self):
        base = Runner([disk(children=[partition('/dev/sdz1', ['/run/media/me/a'])])])
        def replaced(args):
            result = base(args)
            if args[0] == 'udisksctl' and args[1] == 'unmount':
                base.devices[0]['serial'] = 'replacement'
            return result
        result = drives.operate('eject', '/dev/sdz', replaced)
        self.assertFalse(result['ok'])
        self.assertFalse(any('power-off' in args for args in base.calls))

    def test_missing_tool_returns_error(self):
        def missing(args):
            raise FileNotFoundError('udisksctl unavailable')
        self.assertFalse(drives.operate('eject', '/dev/sdz', missing)['ok'])

    def test_open_path_preserves_spaces_and_quotes(self):
        mount = "/run/media/me/Disk ' label"
        run = Runner([disk(children=[partition('/dev/sdz1', [mount])])])
        self.assertTrue(drives.operate('open', '/dev/sdz1', run)['ok'])
        self.assertIn(['xdg-open', mount], run.calls)
        self.assertFalse(drives.operate('open', '/dev/sdz1', Runner([disk()]))['ok'])

    def test_read_only_filesystems_are_mountable(self):
        result = drives.discover(Runner([disk(children=[partition('/dev/sdz1', fs='iso9660')])]))
        self.assertTrue(result[0]['partitions'][0]['supported'])


if __name__ == '__main__':
    unittest.main()
