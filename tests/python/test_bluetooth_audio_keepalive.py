import importlib.util
from pathlib import Path
import unittest

helper = Path(__file__).resolve().parents[2] / ".config/quickshell/helios/services/bluetooth-audio-keepalive.py"

class KeepaliveTest(unittest.TestCase):
    def test_only_idle_default_bluetooth_output_is_woken(self):
        self.assertTrue(helper.exists(), "Bluetooth keepalive helper missing")
        spec = importlib.util.spec_from_file_location("keepalive", helper)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        sinks = [{"index": 4, "name": "bluez_output.headset.1"}, {"index": 5, "name": "alsa_output.speaker"}]
        choose = module.idle_bluetooth_output
        self.assertEqual(choose(sinks[0]["name"], sinks, []), "bluez_output.headset.1")
        self.assertEqual(choose(sinks[1]["name"], sinks, []), "")
        self.assertEqual(choose("missing", sinks, []), "")
        music = {"sink": 4, "corked": False, "properties": {"application.name": "Music"}}
        self.assertEqual(choose(sinks[0]["name"], sinks, [music]), "")
        music["corked"] = True
        self.assertEqual(choose(sinks[0]["name"], sinks, [music]), "bluez_output.headset.1")
        music["corked"] = False
        music["sink"] = 5
        self.assertEqual(choose(sinks[0]["name"], sinks, [music]), "bluez_output.headset.1")
        own = {"sink": 4, "corked": False, "properties": {"application.name": "Helios audio keepalive"}}
        self.assertEqual(choose(sinks[0]["name"], sinks, [own]), "bluez_output.headset.1")
        tap = {"sink": 4, "corked": False, "properties": {"media.name": "helios-tap"}}
        self.assertEqual(choose(sinks[0]["name"], sinks, [own, tap]), "bluez_output.headset.1")

if __name__ == "__main__":
    unittest.main()
