#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
# Private runtime dir: the test bus starts its own portals, which would
# otherwise take over the real session's $XDG_RUNTIME_DIR/doc mount.
mkdir -m 700 "$test_root/runtime"
# Live PipeWire connection; test streams play silence and touch only their own volume.
export PIPEWIRE_REMOTE="${PIPEWIRE_REMOTE:-$XDG_RUNTIME_DIR/pipewire-0}"
export XDG_RUNTIME_DIR="$test_root/runtime"

cp -r "$repo_root/.config/quickshell/helios" "$test_root/helios"
cp "$repo_root/tests/qml/tst_audio_mixer_streams.qml" "$test_root/helios/"
set +e
output="$({
    HOME="$test_root/home" \
    XDG_CONFIG_HOME="$test_root/config" \
    XDG_CACHE_HOME="$test_root/cache" \
    XDG_STATE_HOME="$test_root/state" \
    QT_QPA_PLATFORM="offscreen" \
    QML_IMPORT_PATH="$test_root/helios" \
        timeout 8s dbus-run-session -- qs -vv --no-color --path "$test_root/helios/tst_audio_mixer_streams.qml"
} 2>&1)"
test_status=$?
set -e

printf '%s\n' "$output"

if [[ "$output" != *"AUDIO_MIXER_STREAMS_TEST_PASS"* ]] || [[ "$output" == *"AUDIO_MIXER_STREAMS_TEST_FAIL"* ]]; then
    exit 1
fi

if [[ "$test_status" -eq 124 ]]; then
    printf 'AUDIO_MIXER_STREAMS test timed out\n' >&2
    exit 1
fi
