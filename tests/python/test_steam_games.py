import importlib.util
from pathlib import Path
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[2] / '.config/quickshell/helios/services/steam-games.py'
spec = importlib.util.spec_from_file_location('steam_games', HELPER)
steam = importlib.util.module_from_spec(spec)
spec.loader.exec_module(steam)


def manifest(library, appid, name):
    apps = library / 'steamapps'
    apps.mkdir(parents=True, exist_ok=True)
    (apps / f'appmanifest_{appid}.acf').write_text(f'"AppState"\n{{\n\t"appid"\t\t"{appid}"\n\t"name"\t\t"{name}"\n}}\n')


class SteamGamesTest(unittest.TestCase):
    def test_native_and_flatpak_libraries(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            native = home / '.local/share/Steam'
            extra = home / 'Games/SteamLibrary'
            flatpak = home / '.var/app/com.valvesoftware.Steam/.local/share/Steam'
            manifest(native, '10', 'Native Game')
            manifest(native, '1493710', 'Proton Experimental')
            manifest(extra, '20', 'Second Drive Game')
            manifest(flatpak, '30', 'Flatpak Game')
            manifest(flatpak, '10', 'Native Game')
            (native / 'steamapps/libraryfolders.vdf').write_text(
                f'"libraryfolders"\n{{\n\t"0"\n\t{{\n\t\t"path"\t\t"{native}"\n\t}}\n\t"1"\n\t{{\n\t\t"path"\t\t"{extra}"\n\t}}\n}}\n')
            icon = native / 'appcache/librarycache/10/abc.jpg'
            icon.parent.mkdir(parents=True)
            icon.write_bytes(b'')
            (home / '.steam').mkdir()
            (home / '.steam/steam').symlink_to(native)

            games = steam.games(home)

            self.assertEqual([(g['appid'], g['flatpak']) for g in games], [('10', False), ('20', False), ('30', True)])
            self.assertEqual(games[0]['icon'], str(icon))
            self.assertEqual(games[2]['icon'], '')

    def test_no_steam(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(steam.games(Path(tmp)), [])


if __name__ == '__main__':
    unittest.main()
