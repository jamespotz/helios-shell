#!/usr/bin/env python3
"""Dump local + subscribed calendar events as JSON for services/Calendar.qml.

Local events come from Evolution Data Server — the backend GNOME Calendar
(and anything synced into it via GNOME Online Accounts) already stores
events in. Subscribed events come from user-added ICS/iCal feed URLs
(services/Calendar.qml's addSubscription()), persisted at
~/.cache/helios/calendar-subscriptions.json, fetched fresh on every run.
One-shot: prints a single JSON object and exits, unlike system-info.py's
polling loop, because calendar data changes far less often than system
stats.
"""
import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("ICalGLib", "3.0")
from gi.repository import EDataServer, ECal, ICalGLib  # noqa: E402
import json
import datetime
import os
import urllib.request


WINDOW_DAYS = 180


def fmt(dt):
    return dt.strftime("%Y%m%dT%H%M%SZ")


def window():
    now = datetime.datetime.now()
    return now - datetime.timedelta(days=WINDOW_DAYS), now + datetime.timedelta(days=WINDOW_DAYS)


def collect_local_events():
    registry = EDataServer.SourceRegistry.new_sync(None)
    sources = registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)

    start, end = window()
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

    return events


def load_subscriptions():
    path = os.path.expanduser("~/.cache/helios/calendar-subscriptions.json")
    try:
        with open(path) as f:
            data = json.load(f)
        if isinstance(data, list):
            return data
    except Exception:
        pass
    return []


def event_from_span(component, span, label):
    # The callback's `component` is the recurrence TEMPLATE — its
    # get_dtstart() is the template's original date, the SAME on every
    # invocation for a recurring event. The actual per-occurrence time
    # comes from `span` (a Unix epoch range), not from component.get_dtstart().
    is_all_day = component.get_dtstart().is_date()
    start_epoch = span.get_start()
    end_epoch = span.get_end()

    # All-day dates must be read as UTC — converting through local time
    # risks shifting the date by a day depending on the system's UTC
    # offset. Timed events convert to local time for display, matching
    # how a calendar app shows events in the viewer's own timezone.
    if is_all_day:
        d = datetime.datetime.utcfromtimestamp(start_epoch)
        return {
            "summary": component.get_summary() or "(no title)",
            "date": "%04d-%02d-%02d" % (d.year, d.month, d.day),
            "allDay": True,
            "startTime": None,
            "endTime": None,
            "source": label,
        }

    d = datetime.datetime.fromtimestamp(start_epoch)
    de = datetime.datetime.fromtimestamp(end_epoch)
    return {
        "summary": component.get_summary() or "(no title)",
        "date": "%04d-%02d-%02d" % (d.year, d.month, d.day),
        "allDay": False,
        "startTime": "%02d:%02d" % (d.hour, d.minute),
        "endTime": "%02d:%02d" % (de.hour, de.minute),
        "source": label,
    }


def collect_subscription_events(subscriptions):
    start, end = window()
    start_t = ICalGLib.Time.new_from_string(fmt(start))
    end_t = ICalGLib.Time.new_from_string(fmt(end))

    events = []
    errors = []

    for sub in subscriptions:
        sub_id = sub.get("id", "")
        label = sub.get("label") or "Subscribed calendar"
        url = sub.get("url", "")
        if not url:
            continue

        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "helios-shell-calendar/1.0"}
            )
            with urllib.request.urlopen(req, timeout=10) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            errors.append({"id": sub_id, "label": label, "message": str(e)})
            continue

        try:
            calendar_comp = ICalGLib.Component.new_from_string(raw)
        except Exception as e:
            errors.append(
                {"id": sub_id, "label": label, "message": "could not parse feed: %s" % e}
            )
            continue
        if calendar_comp is None:
            errors.append(
                {"id": sub_id, "label": label, "message": "empty or invalid calendar feed"}
            )
            continue

        occurrences = []

        def on_occurrence(component, span, user_data):
            occurrences.append((component, span))

        vevent = calendar_comp.get_first_component(ICalGLib.ComponentKind.VEVENT_COMPONENT)
        while vevent is not None:
            try:
                vevent.foreach_recurrence(start_t, end_t, on_occurrence, None)
            except Exception:
                pass
            vevent = calendar_comp.get_next_component(ICalGLib.ComponentKind.VEVENT_COMPONENT)

        for component, span in occurrences:
            events.append(event_from_span(component, span, label))

    return events, errors


if __name__ == "__main__":
    try:
        local_events = collect_local_events()
    except Exception:
        local_events = []

    subscription_events, subscription_errors = collect_subscription_events(
        load_subscriptions()
    )

    all_events = local_events + subscription_events
    all_events.sort(key=lambda e: (e["date"], e["startTime"] or ""))

    print(json.dumps({"events": all_events, "subscriptionErrors": subscription_errors}))
