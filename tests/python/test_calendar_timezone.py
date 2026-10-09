import importlib.util
import os
from pathlib import Path
import time
import unittest

HELPER = Path(__file__).resolve().parents[2] / '.config/quickshell/helios/modules/island/calendar-info.py'
spec = importlib.util.spec_from_file_location('calendar_timezone', HELPER)
calendar = importlib.util.module_from_spec(spec)
spec.loader.exec_module(calendar)


class CalendarTimezoneTest(unittest.TestCase):
    def setUp(self):
        self.old_timezone = os.environ.get('TZ')
        os.environ['TZ'] = 'Asia/Manila'
        time.tzset()

    def tearDown(self):
        if self.old_timezone is None:
            os.environ.pop('TZ', None)
        else:
            os.environ['TZ'] = self.old_timezone
        time.tzset()

    def event(self, start, end):
        component = calendar.ICalGLib.Component.new_from_string(
            'BEGIN:VEVENT\nUID:test\nSUMMARY:Test\nDTSTART' + start + '\nDTEND' + end + '\nEND:VEVENT')
        return calendar.local_event(component, 'Test calendar')

    def test_utc_event_crosses_local_midnight(self):
        event = self.event(':20261010T180000Z', ':20261010T190000Z')
        self.assertEqual((event['date'], event['startTime'], event['endTime']), ('2026-10-11', '02:00', '03:00'))

    def test_named_timezone(self):
        event = self.event(';TZID=America/New_York:20261010T090000', ';TZID=America/New_York:20261010T100000')
        self.assertEqual((event['date'], event['startTime'], event['endTime']), ('2026-10-10', '21:00', '22:00'))

    def test_floating_time_remains_local(self):
        event = self.event(':20261010T090000', ':20261010T100000')
        self.assertEqual((event['startTime'], event['endTime']), ('09:00', '10:00'))

    def test_all_day_date_does_not_shift(self):
        event = self.event(';VALUE=DATE:20261010', ';VALUE=DATE:20261011')
        self.assertEqual((event['date'], event['allDay'], event['startTime'], event['endTime']), ('2026-10-10', True, None, None))
