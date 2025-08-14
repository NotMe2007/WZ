import os, json, sys

DATA_DIR = os.path.join(os.getcwd(), 'game data')
os.makedirs(DATA_DIR, exist_ok=True)
path = os.path.join(DATA_DIR, 'settings.json')

# persisted settings we want to test
persisted = {
    "AutoUpgrade": False,
    "Settings": {
        "Dungeon": {
            "Enabled": True,
            "AutoSelectHighest": True
        }
    }
}
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(persisted, fh, indent=2)
print('Wrote', path)

# defaults as in Features/Menu.lua (subset for the test)
def defaults():
    return {
        'AutoUpgrade': True,
        'RemoveDamage': False,
        'AutoChest': True,
        'CoinMagnet': True,
        'Settings': {
            'Dungeon': {
                'Enabled': False,
                'AutoSelectHighest': False,
                'CustomDungeon': { 'DungeonId': 27 }
            },
            'Tower': {
                'Enabled': False,
                'AutoSelectHighest': False,
                'CustomTower': { 'TowerId': 27 }
            },
            'AutoRejoin': { 'Enabled': True, 'Delay': 5 },
            'AutoSell': { 'Enabled': False, 'Common': False, 'Uncommon': False, 'Rare': False, 'Epic': False }
        }
    }

# merge_defaults behavior from Lua: only set values from src into target when target[k] == nil
# We'll simulate that in Python

def merge_defaults(target, src):
    for k, v in src.items():
        if isinstance(v, dict):
            if not isinstance(target.get(k), dict):
                target[k] = {}
            merge_defaults(target[k], v)
        else:
            if target.get(k) is None:
                target[k] = v

# Simulate initial config: deep copy of empty env then merge defaults
config = {}
merge_defaults(config, defaults())
print('\nConfig after applying defaults (before load):')
print(json.dumps(config, indent=2))

# Now simulate loading persisted file and calling merge_defaults(config, persisted)
with open(path, 'r', encoding='utf-8') as fh:
    data = json.load(fh)

merge_defaults(config, data)
print('\nConfig after merge_defaults(config, persisted):')
print(json.dumps(config, indent=2))

# Report expected vs actual for the test assertions (mimic original Lua test expectations)
checks = [
    ('AutoUpgrade', False),
    ('Settings.Dungeon.Enabled', True),
    ('Settings.Dungeon.AutoSelectHighest', True)
]

print('\nAssertions (expected -> actual):')
all_ok = True
for path, expected in checks:
    cur = config
    for p in path.split('.'):
        cur = cur.get(p) if isinstance(cur, dict) else None
    print(path, 'expected=', expected, 'actual=', cur)
    if cur != expected:
        all_ok = False

if all_ok:
    print('\nSMOKE TEST PASSED: persisted values were applied')
    sys.exit(0)
else:
    print('\nSMOKE TEST SHOWS persisted values did NOT OVERRIDE defaults when target already had values (this matches merge_defaults behavior).')
    sys.exit(2)
