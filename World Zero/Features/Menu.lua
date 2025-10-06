-- Menu settings module
-- Provides safe defaults, merges into getgenv() when available,
-- and exposes a small helper API (set/toggle/print).

local game = rawget(_G, 'game') or nil
local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}

local defaults = {
    AutoUpgrade = true,
    RemoveDamage = false,
    AutoChest = true,
    CoinMagnet = true,
    Settings = {
        Dungeon = {
            Enabled = false,
            AutoSelectHighest = false,
            CustomDungeon = { DungeonId = 27 },
        },
        Tower = {
            Enabled = false,
            AutoSelectHighest = false,
            CustomTower = { TowerId = 27 },
        },
        AutoRejoin = {
            Enabled = true,
            Delay = 5,
        },
        AutoSell = {
            Enabled = false,
            Common = false,
            Uncommon = false,
            Rare = false,
            Epic = false,
        },
    },
}

local function deep_copy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k,v in pairs(tbl) do out[k] = deep_copy(v) end
    return out
end

local function merge_defaults(target, src)
    -- only set values that are missing on target; recurse for tables
    for k,v in pairs(src) do
        if type(v) == 'table' then
            if type(target[k]) ~= 'table' then target[k] = {} end
            merge_defaults(target[k], v)
        else
            if target[k] == nil then target[k] = v end
        end
    end
end

-- Build the runtime config by merging defaults into a copy of _genv
local config = deep_copy(_genv)
merge_defaults(config, defaults)

-- If getgenv exists, write missing keys back so other scripts can observe them
if type(rawget(_G, 'getgenv')) == 'function' then
    local g = rawget(_G, 'getgenv')()
    if type(g) == 'table' then merge_defaults(g, defaults) end
end

-- Helper API
local M = {}

-- Attempt to load local saver helper when running in a local Lua environment
local saver = nil
do
    local ok, s = pcall(function()
        if type(dofile) == 'function' then
            return dofile('tools/save_to_game_data.lua')
        end
        return nil
    end)
    if ok and type(s) == 'table' then saver = s end
end

-- Persist current config to disk (best-effort, non-fatal)
function M.save()
    if not saver or type(saver.save_table) ~= 'function' then
        return false, 'no saver available'
    end
    local ok, err = pcall(function() return saver.save_table('settings', config) end)
    if not ok then return false, err end
    return true
end

-- Load persisted config from disk (best-effort). Merges into current config.
function M.load()
    -- try to open the settings file at ./game data/settings.json
    if type(io) ~= 'table' or type(io.open) ~= 'function' then
        return false, 'io not available'
    end
    local path = 'game data/settings.json'
    local fh, err = io.open(path, 'r')
    if not fh then return false, err end
    local content = fh:read('*a')
    fh:close()
    if not content or #content == 0 then return false, 'empty' end

    -- Try Roblox HttpService first (if running in Roblox)
    local ok, data = pcall(function()
        if game and type(game.GetService) == 'function' then
            local HttpService = game:GetService('HttpService')
            if HttpService then
                -- Use pcall when calling JSON decode to avoid errors
                local ok2, dec = pcall(function() return HttpService:JSONDecode(content) end)
                if ok2 then return dec end
            end
        end
        return nil
    end)
    if ok and type(data) == 'table' then
        merge_defaults(config, data)
        return true
    end

    -- Try a common Lua json module
    ok, data = pcall(function() return (require and require('json') and require('json').decode and require('json').decode(content)) end)
    if ok and type(data) == 'table' then
        merge_defaults(config, data)
        return true
    end

    -- Fallback: try to convert JSON-ish to Lua table literal and load it (best-effort, local only)
    local converted = content:gsub('%f[%S]null%f[%s%p]', 'nil')
    converted = converted:gsub('(%b"" )%s*:%s*', function(k) return '['..k..'] = ' end)
    -- also handle keys without trailing space
    converted = converted:gsub('(%b"")%s*:%s*', function(k) return '['..k..'] = ' end)
    local chunk = 'return ' .. converted
    local load_fn = rawget(_G, 'load') or rawget(_G, 'loadstring')
    if type(load_fn) == 'function' then
        local ok2, res = pcall(function() return load_fn(chunk) end)
        if ok2 and type(res) == 'function' then
            local ok3, tbl = pcall(res)
            if ok3 and type(tbl) == 'table' then
                merge_defaults(config, tbl)
                return true
            end
        end
    end
    return false, 'decode failed'
end

function M.set(path, value)
    -- path is dot-separated (e.g. "Settings.Dungeon.Enabled")
    if type(path) ~= 'string' then return false end
    local cur = config
    local parts = {}
    for p in string.gmatch(path, '[^%.]+') do table.insert(parts, p) end
    for i = 1, #parts - 1 do
        local k = parts[i]
        if type(cur[k]) ~= 'table' then cur[k] = {} end
        cur = cur[k]
    end
    cur[parts[#parts]] = value
    -- best-effort persist
    pcall(M.save)
    return true
end

function M.toggle(path)
    local ok = M.set(path, not (M.get and M.get(path) or nil))
    return ok
end

function M.get(path)
    if not path then return config end
    local cur = config
    for p in string.gmatch(path, '[^%.]+') do
        if type(cur) ~= 'table' then return nil end
        cur = cur[p]
        if cur == nil then return nil end
    end
    return cur
end

function M.print()
    pcall(function()
        print('--- Settings ---')
        print(game:GetService('HttpService'):JSONEncode(config))
    end)
end

-- Return the config and API for other scripts
M.config = config
-- Try loading persisted settings (best-effort)
pcall(M.load)
return M