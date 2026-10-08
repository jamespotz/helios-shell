#!/usr/bin/env python3
"""Decode and copy clipboard text without shell interpolation or newline loss."""
import json
import subprocess
import sys


def main():
    try:
        request = json.loads(sys.stdin.readline())
        if request['action'] == 'decode':
            result = subprocess.run(['cliphist', 'decode'], input=request['line'].encode(), capture_output=True, timeout=10, check=True)
            text = result.stdout.decode('utf-8')
            if '\0' in text:
                raise ValueError('Binary clipboard entries cannot be pinned')
            print(json.dumps({'ok': True, 'text': text}))
        elif request['action'] == 'copy':
            subprocess.run(['wl-copy'], input=request['text'].encode(), capture_output=True, timeout=10, check=True)
            print(json.dumps({'ok': True}))
        else:
            raise ValueError('Unknown clipboard action')
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'ok': False, 'error': str(error)}))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
