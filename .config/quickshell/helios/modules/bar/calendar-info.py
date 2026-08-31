#!/usr/bin/env python3
"""Dump local calendar events as JSON for services/Calendar.qml.

Reads Evolution Data Server — the backend GNOME Calendar (and anything
synced into it via GNOME Online Accounts) already stores events in. One-shot:
prints a single JSON array and exits, unlike system-info.py's polling loop,
because calendar data changes far less often than system stats.
"""
import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("ICalGLib", "3.0")
from gi.repository import EDataServer, ECal, ICalGLib  # noqa: E402
import json
import datetime


def fmt(dt):
    return dt.strftime("%Y%m%dT%H%M%SZ")


def collect_events():
    registry = EDataServer.SourceRegistry.new_sync(None)
    sources = registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)

    now = datetime.datetime.now()
    start = now - datetime.timedelta(days=180)
    end = now + datetime.timedelta(days=180)
    sexp = '(occur-in-time-range? (make-time "%s") (make-time "%s"))' % (
        fmt(start),
        fmt(end),
    )

    events = []
    for source in sources:
        try:
            client = ECal.Client.connect_sync(
                source, ECal.ClientSourceType.EVENTS, 5, None
            )
        except Exception:
            continue
        try:
            ok, comps = client.get_object_list_sync(sexp, None)
        except Exception:
            continue
        for comp in comps:
            # get_dtstart()/get_dtend() return an ICalGLib.Time directly (not
            # wrapped in an ECalComponentDateTime.value) and get_summary()
            # returns a plain str directly — both confirmed against a real
            # event in this system's calendar, not assumed from API docs.
            t = comp.get_dtstart()
            if t is None:
                continue
            is_all_day = t.is_date()
            event = {
                "summary": comp.get_summary() or "(no title)",
                "date": "%04d-%02d-%02d" % (t.get_year(), t.get_month(), t.get_day()),
                "allDay": is_all_day,
                "startTime": None
                if is_all_day
                else "%02d:%02d" % (t.get_hour(), t.get_minute()),
                "endTime": None,
                "source": source.get_display_name(),
            }
            te = comp.get_dtend()
            if te is not None and not is_all_day:
                event["endTime"] = "%02d:%02d" % (te.get_hour(), te.get_minute())
            events.append(event)

    events.sort(key=lambda e: (e["date"], e["startTime"] or ""))
    return events


if __name__ == "__main__":
    try:
        print(json.dumps(collect_events()))
    except Exception:
        print(json.dumps([]))
