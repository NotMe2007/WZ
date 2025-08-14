-- Defensive auto-sell module
local game = rawget(_G, 'game') or error('game global missing')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local spawn = function(f) coroutine.wrap(f)() end

local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
local cfg = {
    Common = (_genv.Common == nil) and true or _genv.Common,
    Uncommon = (_genv.Uncommon == nil) and true or _genv.Uncommon,
    Rare = (_genv.Rare == nil) and true or _genv.Rare,
    Epic = (_genv.Epic == nil) and true or _genv.Epic,
    Legendary = (_genv.Legendary == nil) and false or _genv.Legendary,
}

-- Attempt to integrate with Menu settings module if present in ReplicatedStorage.Features.Menu
local MenuModule = nil
local function tryLoadMenu()
    local ok, mod = pcall(function()
        local candidate = ReplicatedStorage:FindFirstChild('Features') and ReplicatedStorage.Features:FindFirstChild('Menu') or nil
        if candidate then return require(candidate) end
        return nil
    end)
    if ok and mod and type(mod.get) == 'function' then
        MenuModule = mod
    else
        MenuModule = nil
    end
end
tryLoadMenu()

local function readAutoSellSettings()
    -- Returns enabled(bool) and interval(number)
    if MenuModule and type(MenuModule.get) == 'function' then
        local enabled = MenuModule.get and MenuModule.get('Settings.AutoSell.Enabled')
        local delay = MenuModule.get and MenuModule.get('Settings.AutoSell.Delay')
        if enabled ~= nil then
            return enabled == true, tonumber(delay) or 5
        end
    end
    -- fallback to _genv
    if _genv.AutoSell and type(_genv.AutoSell) == 'table' then
        return (_genv.AutoSell.Enabled == true), tonumber(_genv.AutoSell.Delay) or 5
    end
    return false, 5
end

local function persistAutoSellSettings(enabled, interval)
    if MenuModule and type(MenuModule.set) == 'function' then
        pcall(function()
            MenuModule.set('Settings.AutoSell.Enabled', enabled)
            MenuModule.set('Settings.AutoSell.Delay', interval)
        end)
        return
    end
    -- fallback to _genv
    if _genv.AutoSell and type(_genv.AutoSell) == 'table' then
        _genv.AutoSell.Enabled = enabled
        _genv.AutoSell.Delay = interval
    else
        _genv.AutoSell = { Enabled = enabled, Delay = interval }
    end
end

local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do RunService.Heartbeat:Wait() end
    else
        RunService.Heartbeat:Wait()
    end
end

local function safeRequire(mod)
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

local function getItemList()
    local list = {}
    local itemsMod = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Items') or nil)
    if type(itemsMod) ~= 'table' then return list end
    for k, v in pairs(itemsMod) do
        if type(v) == 'table' and v.Type and (v.Type == 'Weapon' or v.Type == 'Armor') then
            table.insert(list, v)
        end
    end
    return list
end

local function getProfile()
    local plr = Players.LocalPlayer
    if not plr then
        return nil
    end
    local profiles = ReplicatedStorage:FindFirstChild('Profiles')
    if not profiles then return nil end
    return profiles:FindFirstChild(plr.Name) or profiles:FindFirstChild('NT_Script')
end

local function getItemName()
    local names = {}
    local profile = getProfile()
    if not profile or not profile:FindFirstChild('Inventory') then return names end
    local itemsFolder = profile.Inventory:FindFirstChild('Items')
    if not itemsFolder then return names end
    for _, it in ipairs(itemsFolder:GetChildren()) do
        if (it:FindFirstChild('Level') or it:FindFirstChild('Upgrade') or it:FindFirstChild('UpgradeLimit')) and not string.find(it.Name:lower(), 'pet') then
            table.insert(names, it)
        end
    end
    return names
end

local function ToSell()
    local toSell = {}
    local defs = getItemList()
    local inv = getItemName()
    for _, invItem in ipairs(inv) do
        for _, def in ipairs(defs) do
            if def and def.Name == tostring(invItem) then
                local rarity = (def and def.Rarity)
                if rarity and ((rarity == 1 and cfg.Common) or (rarity == 2 and cfg.Uncommon) or (rarity == 3 and cfg.Rare) or (rarity == 4 and cfg.Epic) or (rarity == 5 and cfg.Legendary)) then
                    table.insert(toSell, invItem)
                end
            end
        end
    end
    return toSell
end

local function SellItem()
    local items = ToSell()
    if #items == 0 then return false end
    local drops = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Drops')
    if not drops or not drops:FindFirstChild('SellItems') then return false end
    pcall(function() drops.SellItems:InvokeServer(items) end)
    return true
end

-- Background auto-sell control
local M = {}
M.running = false

function M.start(interval)
    if M.running then return end
    M.running = true
    interval = tonumber(interval) or readAutoSellSettings()
    -- readAutoSellSettings may return enabled,interval; handle
    if type(interval) == 'table' then interval = interval[2] end
    interval = tonumber(interval) or 5
    persistAutoSellSettings(true, interval)
    spawn(function()
        while M.running do
            pcall(SellItem)
            wait(interval)
        end
    end)
end

function M.stop()
    M.running = false
    persistAutoSellSettings(false, (_genv.AutoSell and _genv.AutoSell.Delay) or 5)
end

function M.getItemList() return getItemList() end
function M.getInventory() return getItemName() end
function M.toSell() return ToSell() end
function M.sellNow() return SellItem() end

-- Auto-start if getgenv configured
if _genv.AutoSell and _genv.AutoSell.Enabled then
    M.start(_genv.AutoSell.Interval or 5)
end

return M