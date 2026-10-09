import importlib.util
from pathlib import Path
import unittest

HELPER = Path(__file__).resolve().parents[2] / '.config/quickshell/helios/modules/island/calendar-info.py'
spec = importlib.util.spec_from_file_location('calendar_info', HELPER)
calendar_info = importlib.util.module_from_spec(spec)
spec.loader.exec_module(calendar_info)
links_in = calendar_info.links_in

# Trimmed from a real Google Calendar Zoom invite (labels changed): a plain-text section, then
# an HTML section repeating the same links behind google.com/url redirects.
ZOOM_INVITE = (
    "Zoom\n"
    "https://us06web.zoom.us/j/123?pwd=abc&omn=9&jst=2 (ID: 123, passcode: 1)\n\n"
    "Instructions: https://www.google.com/url?q=https://applications.zoom.us/addon/invitation/detail?id%3D7&sa=D\n\n"
    'Meeting host: a@b.pet<br /><br />Join Zoom Meeting: <br /><a href="https://www.google.com/url?q=https://us06web.zoom.us/j/123?pwd%3Dabc%26omn%3D9%26jst%3D2&amp;sa=D" target="_blank">https://us06web.zoom.us/j/123?pwd=abc&amp;omn=9&amp;jst=2</a>'
    '<br /><br />Chat with Everyone: <br /><a href="https://www.google.com/url?q=https://us06web.zoom.us/launch/jc/9&amp;sa=D">https://us06web.zoom.us/launch/jc/9</a>'
)


class LinksTest(unittest.TestCase):
    def test_labels_and_dedupes_redirected_links(self):
        self.assertEqual(links_in([ZOOM_INVITE]), [
            {'url': 'https://us06web.zoom.us/j/123?pwd=abc&omn=9&jst=2', 'label': 'Join Zoom meeting'},
            {'url': 'https://applications.zoom.us/addon/invitation/detail?id=7', 'label': 'Joining instructions'},
            {'url': 'https://us06web.zoom.us/launch/jc/9', 'label': 'Zoom chat'},
        ])

    def test_unknown_link_ignores_description_label(self):
        self.assertEqual(links_in(['Sprint board: https://linear.app/team/board'])[0]['label'], '')

    def test_bare_link_has_no_label(self):
        self.assertEqual(links_in(['', 'https://meet.example.com/team.']), [
            {'url': 'https://meet.example.com/team', 'label': ''},
        ])


if __name__ == '__main__':
    unittest.main()
