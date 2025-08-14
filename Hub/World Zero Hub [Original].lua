-- World Zero Hub (cleaned, defensive)

-- Bind Roblox globals for linters
local game = rawget(_G, 'game') or error('game missing')
local Instance = rawget(_G, 'Instance')
local Vector3 = rawget(_G, 'Vector3')
local Color3 = rawget(_G, 'Color3')

-- Services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')
local RunService = game:GetService('RunService')

local function wait(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do RunService.Heartbeat:Wait() end
    else
        RunService.Heartbeat:Wait()
    end
end

-- Configuration (read from getgenv if available, do not inject into _G)
local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
local cfg = {
    coin = _genv.coin or false,
    kill = _genv.kill or false,
    killPlayer = _genv.killPlayer or false,
    damage = _genv.damage or false,
    sprint = _genv.sprint or false,
    effect = _genv.effect or false,
    skip = _genv.skip or false,
    chest = _genv.chest or false,
    feedPet = _genv.feedPet or false,
    upgrade = _genv.upgrade or false,
    range = _genv.range or 10000,
    delay = _genv.dalay or 3.5,
}

-- Wait for game loaded
repeat wait() until game:IsLoaded()

-- Safe require helper
local function safeRequire(mod)
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

-- Wait for player & character
local function getPlayer()
    local plr = Players.LocalPlayer
    while not plr do wait() plr = Players.LocalPlayer end
    local cha = plr.Character or plr.CharacterAdded:Wait()
    while not cha:FindFirstChild('HumanoidRootPart') do wait() end
    local hrp = cha:FindFirstChild('HumanoidRootPart')
    local col = cha:FindFirstChild('Collider') or cha:FindFirstChild('UpperTorso') or cha:FindFirstChild('LowerTorso')
    return plr, cha, hrp, col
end

local player, char, plr, col = getPlayer()

-- Modules
local CombatMod = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Combat') or nil)
local SettingsMod = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Settings') or nil)

-- UI library (guarded)
local loadfunc = rawget(_G, 'loadstring') or rawget(_G, 'load') or load
local library
do
    local ok, res = pcall(function()
        local src = game:HttpGet('https://pastebin.com/raw/FsJak6AT')
        if src and #src > 0 then
            local fn = loadfunc(src)
            if type(fn) == 'function' then return fn() end
        end
    end)
    library = ok and res or nil
end

local UI
if library then
    UI = library:CreateWindow('World Zero Hub')
end

-- Provide Enum and setclipboard safely for linters/runtime
local Enum = rawget(_G, 'Enum') or {}
local setclipboard = rawget(_G, 'setclipboard')

-- Mini UI stub generator when the pastebin UI isn't available
local function ui_stub()
    local t = {}
    function t:Toggle(...) end
    function t:Button(...) end
    function t:Slider(...) end
    function t:Label(...) end
    function t:Bind(...) end
    function t:CreateFolder(...) return t end
    function t:GuiSettings(...) end
    return t
end

-- Create GUIS/Setting/Credit/Update handles; use real library when available
local GUIS, Setting, Credit, Update
if library and UI then
    local miscWindow = library:CreateWindow('Misc')
    GUIS = miscWindow:CreateFolder('Open Guis')
    Setting = UI:CreateFolder('Settings')
    Credit = UI:CreateFolder('Credit')
    Update = UI:CreateFolder('Latest Updated')
else
    GUIS = ui_stub()
    Setting = ui_stub()
    Credit = ui_stub()
    Update = ui_stub()
end

-- Safe firetouch wrapper if available
local _firetouch = rawget(_G, 'firetouchinterest')

-- Utility: find mobs/players in range
local function findTargets()
    local mobs, poses = {}, {}
    if Workspace:FindFirstChild('Mobs') then
        for _,v in ipairs(Workspace.Mobs:GetChildren()) do
            pcall(function()
                if v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then
                    local dist = (v.Collider.Position - plr.Position).magnitude
                    if dist < cfg.range then table.insert(mobs, v); table.insert(poses, plr.Position) end
                end
            end)
        end
    end
    if cfg.killPlayer and Workspace:FindFirstChild('Characters') then
        for _,p in ipairs(Workspace.Characters:GetChildren()) do
            pcall(function()
                if p:FindFirstChild('Collider') and p:FindFirstChild('HealthProperties') and p.HealthProperties.Health.Value > 0 then
                    local dist = (p.Collider.Position - plr.Position).magnitude
                    if dist < cfg.range then table.insert(mobs, p); table.insert(poses, plr.Position) end
                end
            end)
        end
    end
    return mobs, poses
end

-- Simple helper to get food item
local function getFood()
    local profiles = ReplicatedStorage:FindFirstChild('Profiles')
    if not profiles then return nil, 0 end
    local proto = profiles:FindFirstChild(char.Name) or profiles:FindFirstChild('NT_Script')
    if not proto or not proto:FindFirstChild('Inventory') then return nil, 0 end
    local items = proto.Inventory:FindFirstChild('Items')
    if not items then return nil, 0 end
    local choices = {'Strawberry','Doughnut','CakeSlice','Sundae'}
    for _,name in ipairs(choices) do
        local it = items:FindFirstChild(name)
        if it and it:FindFirstChild('Count') and it.Count.Value > 0 then return it, it.Count.Value end
    end
    return nil, 0
end

-- Upgrade equipment (best-effort)
local function upgradeEquip()
    local profile = ReplicatedStorage:FindFirstChild('Profiles') and ReplicatedStorage.Profiles:FindFirstChild(char.Name)
    if not profile or not profile:FindFirstChild('Equip') then return end
    for _,v in ipairs(profile.Equip:GetDescendants()) do
        if v:FindFirstChild('UpgradeLimit') then
            pcall(function()
                ReplicatedStorage.Shared.ItemUpgrade.Upgrade:FireServer(v)
            end)
        end
    end
end

-- Background loops
-- coin magnet
coroutine.wrap(function()
    while true do
        if cfg.coin and plr and Workspace:FindFirstChild('Coins') then
            for _,v in ipairs(Workspace.Coins:GetChildren()) do
                if v.Name == 'CoinPart' then
                    pcall(function()
                        v.CanCollide = false
                        if plr then v.CFrame = plr.CFrame end
                    end)
                end
            end
        end
        wait(0.5)
    end
end)()

-- kill aura
coroutine.wrap(function()
    while true do
        if cfg.kill and CombatMod then
            local mobs, poses = findTargets()
            if #mobs > 0 then
                -- try attack with default skillset if available
                pcall(function()
                    for _,skill in ipairs({'Default','Auto'}) do
                        if CombatMod and CombatMod.AttackTargets then
                            CombatMod.AttackTargets(nil, mobs, poses, skill)
                        end
                    end
                end)
            end
        end
        wait(cfg.delay)
    end
end)()

-- auto chest
coroutine.wrap(function()
    while true do
        if cfg.chest and plr then
            for _,v in ipairs(Workspace:GetChildren()) do
                if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
                    pcall(function() if plr and v.PrimaryPart then v.PrimaryPart.CFrame = plr.CFrame end end)
                end
            end
        end
        wait(0.5)
    end
end)()

-- auto feed pet
coroutine.wrap(function()
    while true do
        if cfg.feedPet then
            local food, count = getFood()
            if food then pcall(function() ReplicatedStorage.Shared.Pets.FeedPet:FireServer(food, true) end) end
            wait(0.1)
        end
        wait(0.5)
    end
end)()

-- auto upgrade
coroutine.wrap(function()
    while true do
        if cfg.upgrade then pcall(upgradeEquip) end
        wait(0.25)
    end
end)()

-- remove damage numbers
Workspace.ChildAdded:Connect(function(v)
    if cfg.damage and v and v.Name == 'DamageNumber' then pcall(function() v:Destroy() end) end
end)

-- skip cutscenes (best-effort)
do
    local ok, Camera = pcall(function() return require(ReplicatedStorage.Client.Camera) end)
    if ok and player.PlayerGui and player.PlayerGui:FindFirstChild('CutsceneUI') then
        player.PlayerGui.CutsceneUI.Changed:Connect(function()
            if cfg.skip and Camera and type(Camera.SkipCutscene) == 'function' then pcall(function() Camera:SkipCutscene() end) end
        end)
    end
end

-- UI and bindings
if library and UI then
    local CombatTab = UI:CreateFolder('Combat')
    local MiscTab = UI:CreateFolder('Misc')

    CombatTab:Toggle('Kill Aura', function(val) cfg.kill = val end)
    CombatTab:Toggle('PvP Arena', function(val) cfg.killPlayer = val end)
    CombatTab:Slider('Range', 0, 10000, false, function(v) cfg.range = v end)
    CombatTab:Slider('Delay', 1, 10, true, function(v) cfg.delay = v end)

    MiscTab:Toggle('Coin Magnet', function(v) cfg.coin = v end)
    MiscTab:Toggle('Auto Chest', function(v) cfg.chest = v end)
    MiscTab:Toggle('Auto Feed Pet', function(v) cfg.feedPet = v end)
    MiscTab:Toggle('Remove Damage', function(v) cfg.damage = v end)
    MiscTab:Toggle('Fast Upgrade', function(v) cfg.upgrade = v end)
    MiscTab:Toggle('Skip Cutscenes', function(v) cfg.skip = v end)

    local Teleports = UI:CreateFolder('Teleports')
    Teleports:Button('World 1', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(13) end) end)
    Teleports:Button('World 2', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(19) end) end)
    Teleports:Button('World 3', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(20) end) end)
    Teleports:Button('World 4', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(29) end) end)
    Teleports:Button('World 5', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(31) end) end)
    Teleports:Button('World 6', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(36) end) end)
    Teleports:Button('World 7', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(40) end) end)
    Teleports:Button('PvP Arena', function() pcall(function() ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(39) end) end)
end

-- End of hub
GUIS:Button("Open Sell",function()
    sell = require(game:GetService("ReplicatedStorage").Client.Gui.GuiScripts.Sell)
    sell:Open()
end)

-- Open Bank
GUIS:Button("Open Bank",function()
    bank = require(game:GetService("ReplicatedStorage").Client.Gui.GuiScripts.Bank)
    bank:Open()
end)

--Open Upgrade
GUIS:Button("Open Upgrade",function()
    upgrade = require(game:GetService("ReplicatedStorage").Client.Gui.GuiScripts.ItemUpgrade)
    upgrade:Open()
end)

-- Open Dungeon
GUIS:Button("Open Dungeon",function()
    upgrade = require(game:GetService("ReplicatedStorage").Client.Gui.GuiScripts.MissionSelect)
    upgrade:Open()
end)

-- Open Teleport
GUIS:Button("Open Teleport",function()
    tp = require(game:GetService("ReplicatedStorage").Client.Gui.GuiScripts.WorldTeleport)
    tp:Open()
end)

-- UI Setting --
Setting:GuiSettings()

-- GUI Toggle
Setting:Bind("GUI Toggle",Enum.KeyCode.LeftAlt,function() -- LeftCtrl
    close = game:GetService("CoreGui"):GetChildren()
    if close[9].Enabled then
        close[9].Enabled = false
    else
        close[9].Enabled = true
    end
end)

-- Credit
Credit:Label("Scirpt: LuckyToT#0001",{
    TextSize = 16;
    TextColor = Color3.fromRGB(255,255,255);
    BgColor = Color3.fromRGB(38,38,38);
})

Credit:Button("Copy user",function()
    if not setclipboard then return player:Kick('Bye not support') end
    setclipboard("LuckyToT#0001")
end)

Update:Label("07/10/21",{
    TextSize = 20;
    TextColor = Color3.fromRGB(255,255,255);
    BgColor = Color3.fromRGB(38,38,38);
})
