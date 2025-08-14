
-- Defensive World Zero Hub (old -> cleaned)

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

-- Read config from getgenv if available
local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
local cfg = {
    coin = _genv.coin or false,
    kill = _genv.kill or false,
    killPlayer = _genv.killPlayer or false,
    damage = _genv.damage or false,
    sprint = _genv.sprint or 28,
    jump = _genv.jump or 70,
    effect = _genv.effect or false,
    skip = _genv.skip or false,
    chest = _genv.chest or false,
    feedPet = _genv.feedPet or false,
    upgrade = _genv.upgrade or false,
    range = _genv.range or 10000,
    delay = _genv.dalay or 1,
}

-- Safe require helper
local function safeRequire(mod)
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

-- Wait for local player and character
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

-- Modules (guarded)
local CombatMod = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Combat') or nil)
local SettingsMod = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Settings') or nil)

-- Classes table (kept intact)
local Classes = {
    ["Swordmaster"]     = {"Swordmaster1", "Swordmaster2", "Swordmaster3", "Swordmaster4", "Swordmaster5", "Swordmaster6", "CrescentStrike1", "CrescentStrike2", "CrescentStrike3", "Leap"};
    ["Mage"]            = {"Mage1", "ArcaneBlastAOE", "ArcaneBlast", "ArcaneWave1", "ArcaneWave2", "ArcaneWave3", "ArcaneWave4", "ArcaneWave5", "ArcaneWave6", "ArcaneWave7", "ArcaneWave8", "ArcaneWave9"};
    ["Defender"]        = {"Defender1", "Defender2", "Defender3", "Defender4", "Defender5", "Groundbreaker", "Spin1", "Spin2", "Spin3", "Spin4", "Spin5"};
    ["DualWielder"]     = {"DualWield1", "DualWield2", "DualWield3", "DualWield4", "DualWield5", "DualWield6", "DualWield7", "DualWield8", "DualWield9", "DualWield10", "DashStrike", "CrossSlash1", "CrossSlash2", "CrossSlash3", "CrossSlash4"};
    ["Guardian"]        = {"Guardian1", "Guardian2", "Guardian3", "Guardian4", "SlashFury1", "SlashFury2", "SlashFury3", "SlashFury4", "SlashFury5", "SlashFury6", "SlashFury7", "SlashFury8", "SlashFury9", "SlashFury10", "SlashFury11", "SlashFury12", "SlashFury13", "RockSpikes1", "RockSpikes2", "RockSpikes3"};
    ["IcefireMage"]     = {"IcefireMage1", "IcySpikes1", "IcySpikes2", "IcySpikes3", "IcySpikes4", "IcefireMageFireballBlast", "IcefireMageFireball", "LightningStrike1", "LightningStrike2", "LightningStrike3", "LightningStrike4", "LightningStrike5", "IcefireMageUltimateFrost", "IcefireMageUltimateMeteor1"};
    ["Berserker"]       = {"Berserker1", "Berserker2", "Berserker3", "Berserker4", "Berserker5", "Berserker6", "AggroSlam", "GigaSpin1", "GigaSpin2", "GigaSpin3", "GigaSpin4", "GigaSpin5", "GigaSpin6", "GigaSpin7", "GigaSpin8", "Fissure1", "Fissure2", "FissureErupt1", "FissureErupt2", "FissureErupt3", "FissureErupt4", "FissureErupt5"};
    ["Paladin"]         = {"Paladin1", "Paladin2", "Paladin3", "Paladin4", "LightThrust1", "LightThrust2", "LightPaladin1", "LightPaladin2"};
    ["MageOfLight"]     = {"MageOfLight", "MageOfLightBlast"};
    ["Demon"]           = {"Demon1", "Demon4", "Demon7", "Demon10", "Demon13", "Demon16", "Demon19", "Demon22", "Demon25", "DemonDPS1", "DemonDPS2", "DemonDPS3", "DemonDPS4", "DemonDPS5", "DemonDPS6", "DemonDPS7", "DemonDPS8", "DemonDPS9", "ScytheThrowDPS1", "ScytheThrowDPS2", "ScytheThrowDPS3", "DemonLifeStealDPS", "DemonSoulDPS1", "DemonSoulDPS2", "DemonSoulDPS3"};
    ['Dragoon']          = {'Dragoon1', 'Dragoon2', 'Dragoon3', 'Dragoon4', 'Dragoon5', 'Dragoon6', 'Dragoon7', 'DragoonDash','DragoonCross1', 'DragoonCross2', 'DragoonCross3', 'DragoonCross4', 'DragoonCross5', 'DragoonCross6', 'DragoonCross7', 'DragoonCross8', 'DragoonCross9', 'DragoonCross10', 'MultiStrike1', 'MultiStrike2', 'MultiStrike3', 'MultiStrike4', 'MultiStrike5', 'MultiStrikeDragon1', 'MultiStrikeDragon2', 'MultiStrikeDragon3', 'DragoonFall'};
    ['Archer']           = {'Archer','PiercingArrow1','PiercingArrow2','PiercingArrow3', 'PiercingArrow4', 'PiercingArrow5', 'PiercingArrow5', 'PiercingArrow6', 'PiercingArrow7', 'PiercingArrow8', 'PiercingArrow9', 'PiercingArrow10','SpiritBomb','MortarStrike1','MortarStrike2','MortarStrike3','MortarStrike4','MortarStrike5','MortarStrike6','MortarStrike7', 'HeavenlySword1', 'HeavenlySword2', 'HeavenlySword3', 'HeavenlySword4', 'HeavenlySword5', 'HeavenlySword6'};
}

-- Optionally disable attack event handlers if available
do
    local ok, getEvent = pcall(function()
        local c = ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Combat')
        if c then
            local mod = require(c)
            if mod and type(mod.GetAttackEvent) == 'function' then
                return mod:GetAttackEvent()
            end
        end
    end)

    if ok and getEvent then
        local gc = rawget(_G, 'getconnections')
        if type(gc) == 'function' then
            pcall(function()
                for _, v in next, gc(getEvent.OnClientEvent) do
                    v:Disable()
                end
            end)
        end
    end
end

-- Find targets (mobs + optional players)
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

-- get food to feed the pet
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

-- upgrade equipment
local function upgradeEquip()
    local profiles = ReplicatedStorage:FindFirstChild('Profiles')
    local profile = profiles and profiles:FindFirstChild(char.Name)
    if not profile or not profile:FindFirstChild('Equip') then return end
    for _,v in ipairs(profile.Equip:GetDescendants()) do
        if v:FindFirstChild('UpgradeLimit') then
            pcall(function() ReplicatedStorage.Shared.ItemUpgrade.Upgrade:FireServer(v) end)
        end
    end
end

-- Background loops
coroutine.wrap(function()
    while true do
        if cfg.coin and plr and Workspace:FindFirstChild('Coins') then
            for _,v in ipairs(Workspace.Coins:GetChildren()) do
                if v.Name == 'CoinPart' then
                    pcall(function() v.CanCollide = false if plr and v then v.CFrame = plr.CFrame end end)
                end
            end
        end
        wait(0.5)
    end
end)()

coroutine.wrap(function()
    while true do
        if cfg.kill and CombatMod then
            local mobs, poses = findTargets()
            if #mobs > 0 then
                pcall(function()
                    if CombatMod.AttackTargets then CombatMod.AttackTargets(nil, mobs, poses, 'Default') end
                end)
            end
        end
        wait(cfg.delay)
    end
end)()

coroutine.wrap(function()
    while true do
        if cfg.chest and plr then
            for _,v in ipairs(Workspace:GetChildren()) do
                if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
                    pcall(function() if v.PrimaryPart then v.PrimaryPart.CFrame = plr.CFrame end end)
                end
            end
        end
        wait(0.5)
    end
end)()

coroutine.wrap(function()
    while true do
        if cfg.feedPet then
            local food = getFood()
            if food then pcall(function() ReplicatedStorage.Shared.Pets.FeedPet:FireServer(food, true) end) end
            wait(0.1)
        end
        wait(0.5)
    end
end)()

coroutine.wrap(function()
    while true do
        if cfg.upgrade then pcall(upgradeEquip) end
        wait(0.25)
    end
end)()

Workspace.ChildAdded:Connect(function(v)
    if cfg.damage and v and v.Name == 'DamageNumber' then pcall(function() v:Destroy() end) end
end)

do
    local ok, Camera = pcall(function() return safeRequire(ReplicatedStorage.Client and ReplicatedStorage.Client.Camera or nil) end)
    if ok and Camera and player and player.PlayerGui and player.PlayerGui:FindFirstChild('CutsceneUI') then
        player.PlayerGui.CutsceneUI.Changed:Connect(function()
            if cfg.skip and Camera and type(Camera.SkipCutscene) == 'function' then pcall(function() Camera:SkipCutscene() end) end
        end)
    end
end

-- UI loader and stubs
-- UI loader replaced with a stub that aborts when the UI is invoked.
-- When consumers call `library:CreateWindow(...)` it will kick the player and stop execution.
local loadfunc = rawget(_G, 'loadstring') or rawget(_G, 'load') or load
local library = {
    CreateWindow = function(...)
        pcall(function()
            local plr = game and game.Players and game.Players.LocalPlayer
            if plr and type(plr.Kick) == 'function' then
                plr:Kick('Script was discontinued')
            end
        end)
        error('Script was discontinued')
    end,
}

-- Provide Enum and setclipboard safely
local Enum = rawget(_G, 'Enum') or {}
local setclipboard = rawget(_G, 'setclipboard')

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

local GUIS, Setting, Credit, Update
local UI
if library and type(library.CreateWindow) == 'function' then
    local ok, u = pcall(function() return library:CreateWindow('World Zero Hub') end)
    if ok and u then
        UI = u
        if type(UI.CreateFolder) == 'function' then
            local ok1, g = pcall(function() return UI:CreateFolder('Open Guis') end)
            local ok2, s = pcall(function() return UI:CreateFolder('Settings') end)
            local ok3, c = pcall(function() return UI:CreateFolder('Credit') end)
            local ok4, up = pcall(function() return UI:CreateFolder('Latest Updated') end)
            GUIS = ok1 and g or ui_stub()
            Setting = ok2 and s or ui_stub()
            Credit = ok3 and c or ui_stub()
            Update = ok4 and up or ui_stub()
        else
            GUIS = ui_stub()
            Setting = ui_stub()
            Credit = ui_stub()
            Update = ui_stub()
        end
    else
        GUIS = ui_stub()
        Setting = ui_stub()
        Credit = ui_stub()
        Update = ui_stub()
    end
else
    GUIS = ui_stub()
    Setting = ui_stub()
    Credit = ui_stub()
    Update = ui_stub()
end

-- UI bindings (guarded)
do
    -- Combat / Misc toggles
    if UI or true then
    -- These calls are safe (they use cfg) and will be no-ops if UI is stubbed
    local CombatTab = ui_stub()
    if UI and UI.CreateFolder then pcall(function() CombatTab = UI:CreateFolder('Combat') end) end
    local MiscTab = ui_stub()
    if UI and UI.CreateFolder then pcall(function() MiscTab = UI:CreateFolder('Misc') end) end

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
    end

    -- Teleports (guarded fire)
    local function safeTeleport(id)
        pcall(function() if ReplicatedStorage.Shared and ReplicatedStorage.Shared.Teleport and ReplicatedStorage.Shared.Teleport.TeleportToHub then ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(id) end end)
    end
    if GUIS and GUIS.CreateFolder then
        local Lobbies = ui_stub()
        if UI and UI.CreateFolder then pcall(function() Lobbies = UI:CreateFolder('Teleports') end) end
        Lobbies:Button('World 1', function() safeTeleport(13) end)
        Lobbies:Button('World 2', function() safeTeleport(19) end)
        Lobbies:Button('World 3', function() safeTeleport(20) end)
        Lobbies:Button('World 4', function() safeTeleport(29) end)
        Lobbies:Button('World 5', function() safeTeleport(31) end)
        Lobbies:Button('World 6', function() safeTeleport(36) end)
        Lobbies:Button('World 7', function() safeTeleport(40) end)
        Lobbies:Button('PvP Arena', function() safeTeleport(39) end)
    end

    -- Open other GUI buttons
    GUIS:Button('Open Sell', function()
        pcall(function()
            local ok, sell = pcall(function() return require(ReplicatedStorage.Client.Gui.GuiScripts.Sell) end)
            if ok and sell and type(sell.Open) == 'function' then sell:Open() end
        end)
    end)

    GUIS:Button('Open Bank', function()
        pcall(function()
            local ok, bank = pcall(function() return require(ReplicatedStorage.Client.Gui.GuiScripts.Bank) end)
            if ok and bank and type(bank.Open) == 'function' then bank:Open() end
        end)
    end)

    GUIS:Button('Open Upgrade', function()
        pcall(function()
            local ok, up = pcall(function() return require(ReplicatedStorage.Client.Gui.GuiScripts.ItemUpgrade) end)
            if ok and up and type(up.Open) == 'function' then up:Open() end
        end)
    end)

    GUIS:Button('Open Dungeon', function()
        pcall(function()
            local ok, ms = pcall(function() return require(ReplicatedStorage.Client.Gui.GuiScripts.MissionSelect) end)
            if ok and ms and type(ms.Open) == 'function' then ms:Open() end
        end)
    end)

    GUIS:Button('Open Teleport', function()
        pcall(function()
            local ok, tp = pcall(function() return require(ReplicatedStorage.Client.Gui.GuiScripts.WorldTeleport) end)
            if ok and tp and type(tp.Open) == 'function' then tp:Open() end
        end)
    end)

    -- Setting helpers
    local hideTable = {
        ['RobloxGui'] = true,
        ['CoreScriptLocalization'] = true,
        ['TeleportGui'] = true,
        ['RobloxPromptGui'] = true,
        ['PurchasePromptApp'] = true,
        ['RobloxNetworkPauseNotification'] = true,
        ['TopBar'] = true,
    }

    Setting:GuiSettings()
    Setting:Bind('GUI Toggle', Enum.KeyCode and Enum.KeyCode.LeftAlt or 0, function()
        for _,v in pairs(game:GetService('CoreGui'):GetChildren()) do
            if not hideTable[v.Name] then
                pcall(function() v.Enabled = not v.Enabled end)
            end
        end
    end)

    Credit:Label('Script: LuckyToT#0001', { TextSize = 16; TextColor = Color3.fromRGB(255,255,255); BgColor = Color3.fromRGB(38,38,38); })
    Credit:Button('Copy user', function()
        if not setclipboard then return player:Kick('Bye not support') end
        pcall(function() setclipboard('LuckyToT#0001') end)
    end)

    Update:Label('07/10/21', { TextSize = 20; TextColor = Color3.fromRGB(255,255,255); BgColor = Color3.fromRGB(38,38,38); })
end
