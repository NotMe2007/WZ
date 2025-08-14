#!/usr/bin/env python3
"""Small CLI to read and pretty-print saved settings from game data/settings.json
Usage: python tools/read_settings.py [path]
"""
import sys, os, json

path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.getcwd(), 'game data', 'settings.json')
if not os.path.isfile(path):
    print('No settings file found at', path)
    sys.exit(2)
try:
    with open(path, 'r', encoding='utf-8') as fh:
        data = json.load(fh)
    print(json.dumps(data, indent=2, ensure_ascii=False))
except Exception as e:
    print('Error reading settings:', e)
    sys.exit(1)
