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
return M