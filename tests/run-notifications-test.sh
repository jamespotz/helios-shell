#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

if [[ -n "${NOTIFICATIONS_TEST_CLASS:-}" ]]; then
    if [[ -z "${NOTIFICATIONS_TEST_ADDRESS:-}" ]]; then
        NOTIFICATIONS_TEST_ADDRESS="$(
            hyprctl -j clients \
                | jq -r --arg class "$NOTIFICATIONS_TEST_CLASS" \
                    '.[] | select(.class == $class or .initialClass == $class) | .address' \
                | head -n 1
        )"
        export NOTIFICATIONS_TEST_ADDRESS
    fi

    if [[ -z "$NOTIFICATIONS_TEST_ADDRESS" ]]; then
        printf 'No Hyprland window found for class %s\n' "$NOTIFICATIONS_TEST_CLASS" >&2
        exit 1
    fi

    active_address="$(hyprctl -j activewindow | jq -r '.address')"
    if [[ "${active_address,,}" == "${NOTIFICATIONS_TEST_ADDRESS,,}" ]]; then
        printf 'Integration target %s must start unfocused\n' "$NOTIFICATIONS_TEST_CLASS" >&2
        exit 1
    fi
fi

set +e
output="$({
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$repo_root/.config/quickshell/helios" \
        timeout 5s dbus-run-session -- qs -vv --no-color --path "$repo_root/tests/qml/tst_notifications.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"

if [[ "$output" != *"NOTIFICATIONS_TEST_PASS"* ]] || [[ "$output" == *"NOTIFICATIONS_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'Notification test timed out\n' >&2
    exit 1
fi
