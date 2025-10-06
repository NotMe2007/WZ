-- example_save.lua
-- Demonstrates using tools/save_to_game_data.lua

-- Use dofile to load the helper (works when you run the script from repo root)
local saver = dofile('tools/save_to_game_data.lua')

-- ensure the folder exists
saver.ensure()

-- save a player profile table
local profile = {
    name = 'PlayerOne',
    level = 12,
    inventory = { 'Sword', 'Shield', 'Potion' },
    stats = { hp = 123, mp = 45 }
}

local ok, err = saver.save_table('player_profile', profile)
if not ok then print('Save failed:', err) else print('Saved player_profile to "game data/player_profile.json"') end

-- append runtime log
saver.append_log('session', 'Saved player_profile at '..os.date())

-- save a small text file
saver.save_text('notes', 'This is a development dump file.')

print('Done. Check the "game data" folder in the current directory.')
