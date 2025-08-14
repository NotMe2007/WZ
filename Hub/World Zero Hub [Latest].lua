-- Safe shim locals for static analysis and varying executor environments
local _G_game = rawget(_G, 'game') or nil -- keep reference for tooling
-- Lightweight shims for common Roblox globals so static checks don't fail.
local wait = rawget(_G, 'wait') or function(s)
    local s = tonumber(s) or 0.05
    local t0 = os.clock()
    while os.clock() - t0 < s do end
end
local spawn = rawget(_G, 'spawn') or function(fn)
    local co = coroutine.create(fn)
    coroutine.resume(co)
end
local getgenv = rawget(_G, 'getgenv') or function() return _G end
local getconnections = rawget(_G, 'getconnections') or function() return {} end
local setclipboard = rawget(_G, 'setclipboard') or function() end
local game = rawget(_G, 'game') or _G_game
local Enum = rawget(_G, 'Enum') or (game and game.Enum) or {}
-- Minimal Color3 shim for static tools
local Color3 = rawget(_G, 'Color3') or { fromRGB = function(r,g,b) return {r=r,g=g,b=b} end }

getgenv().coin = false
getgenv().kill = false
getgenv().killPlayer = false
getgenv().damage = false
getgenv().sprint = false
getgenv().effect = false
getgenv().skip = false
getgenv().chest = false
getgenv().feedPet = false
getgenv().upgrade = false

getgenv().sprint = 28
getgenv().jump = 70

-- auto sell
getgenv().Common = false
getgenv().Uncommon = false
getgenv().Rare = false
getgenv().Epic = false
-- getgenv().Legendary = false

getgenv().range = 10000
getgenv().dalay = 3.5

-- Gui color
_G.ToggleColor = Color3.fromRGB(0,255,0)
_G.ButtonColor = Color3.fromRGB(0,255,0)
_G.SliderColor = Color3.fromRGB(0,255,0)

-- wait for the game load
repeat wait() until game:IsLoaded()

-- resilient connection iterator
local function safeIterConnections(evt)
    local gc = rawget(_G, 'getconnections')
    if type(gc) == 'function' then
        local ok, res = pcall(function() if evt then return gc(evt) else return gc() end end)
        if ok and type(res) == 'table' then return res end
    end
    if evt and type(evt.GetConnections) == 'function' then
        local ok2, res2 = pcall(function() return evt:GetConnections() end)
        if ok2 and type(res2) == 'table' then return res2 end
    end
    return {}
end

-- Check require
if not require then
    game.Players.LocalPlayer:Kick('Bye not support')
    wait(5)
    return game:Shutdown()
end

if not getconnections then
    game.Players.LocalPlayer:Kick('Bye not support')
    wait(5)
    return game:Shutdown()
end

-- cheak date time
-- day = os.date('%d')
-- month = os.date('%m')
-- year = os.date('%Y')

-- if tonumber(year) ~= 2021 then
--     game.Players.LocalPlayer:Kick('Why ;(')
--     wait(5)
-- 	return game:Shutdown()
-- elseif tonumber(month) ~= 6 then
--     game.Players.LocalPlayer:Kick('Why ;(')
--     wait(5)
--     return game:Shutdown() 
-- elseif tonumber(day) > 20 then
--     game.Players.LocalPlayer:Kick('Why ;(')
--     wait(5)
-- 	return game:Shutdown()
-- end

-- check

-- Check the player
function getPlayer()
    local player, cha, plr, col, torso = nil, nil, nil, nil, nil

    while not game.Players.LocalPlayer do
        wait()
    end

    while not game.Players.LocalPlayer.Character do
        print('Waiting2')
        wait()
    end

    while not game.Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart') do
        print('Waiting3')
        wait()
    end

    while not game.Players.LocalPlayer.Character:FindFirstChild('Collider') do
        print('Waiting4')

        wait()
    end

    while not game.Players.LocalPlayer.Character:FindFirstChild('LowerTorso') do
        print('Waiting5')
        wait()
    end

    while not game.Players.LocalPlayer.Character:FindFirstChild('Humanoid') do
        print('Waiting6')
        wait()
    end

    local player = game.Players.LocalPlayer
    local cha = player.Character
    local hum = cha.Humanoid
    local col = cha.Collider
    local torso = cha.LowerTorso
    local plr = cha.HumanoidRootPart
    return player, cha, plr, hum, col, torso

end
local player, cha, plr, hum, col, torso = getPlayer()

-- Safe require helper to avoid hard crashes when a module is missing
local function safeRequire(mod)
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

-- Variables (guarded)
local Combat = safeRequire(game:GetService("ReplicatedStorage").Shared.Combat)
local GetEvent = Combat and Combat.GetAttackEvent and Combat:GetAttackEvent()
local st = safeRequire(game:GetService("ReplicatedStorage").Shared.Settings) or {}

local ProfilesFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Profiles")
local CharProfileCheck = nil
if ProfilesFolder and ProfilesFolder:FindFirstChild(cha.Name) then
    CharProfileCheck = ProfilesFolder[cha.Name]
end
local ClassGUI = (CharProfileCheck and CharProfileCheck:FindFirstChild('Class') and CharProfileCheck.Class) or { Value = 'Swordmaster' }

-- Table classes
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
	['Archer']			= {'Archer','PiercingArrow1','PiercingArrow2','PiercingArrow3', 'PiercingArrow4', 'PiercingArrow5', 'PiercingArrow5', 'PiercingArrow6', 'PiercingArrow7', 'PiercingArrow8', 'PiercingArrow9', 'PiercingArrow10','SpiritBomb','MortarStrike1','MortarStrike2','MortarStrike3','MortarStrike4','MortarStrike5','MortarStrike6','MortarStrike7', 'HeavenlySword1', 'HeavenlySword2', 'HeavenlySword3', 'HeavenlySword4', 'HeavenlySword5', 'HeavenlySword6'};
}

-- bypass
-- disable client handlers where possible
if (GetEvent) then
    pcall(function()
        for _, v in next, safeIterConnections(GetEvent.OnClientEvent) do
            pcall(function() if v and v.Disable then v:Disable() end end)
        end
    end)
end


-- Get moster
function monster()
    local mob = {}
    local pos = {}
    local player, cha, plr, hum, col, torso = getPlayer()
    for i,v in pairs(game:GetService("Workspace").Mobs:GetChildren()) do
        pcall(function()
            if v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then
                local distance = (v.Collider.Position - plr.Position).magnitude
                if distance < getgenv().range then
                    table.insert(mob, v)
                    table.insert(pos, plr.Position)
                end
            end
        end)
    end
    if getgenv().killPlayer then
        for i, p in pairs(game:GetService("Workspace").Characters:GetChildren()) do
            pcall(function()
                if p:FindFirstChild('Collider') and p:FindFirstChild('HealthProperties') and p.HealthProperties.Health.Value > 0 then
                    local distance = (p.Collider.Position - plr.Position).magnitude
                    if distance < getgenv().range then
                        table.insert(mob, p)
                        table.insert(pos, plr.Position)
                    end
                end
            end)
        end
   end
    return mob, pos
end

-- get food to feed the pet
function getFood()
    local Items = game:GetService("ReplicatedStorage").Profiles[cha.Name].Inventory.Items
    local foodToFeed, foodValue = nil, nil
    if Items:FindFirstChild("Strawberry") and Items.Strawberry.Count.Value > 0 then
        foodToFeed = game:GetService("ReplicatedStorage").Profiles[cha.Name].Inventory.Items.Strawberry
        foodValue = Items.Strawberry.Count.Value
    elseif Items:FindFirstChild("Doughnut") and Items.Doughnut.Count.Value > 0 then
        foodToFeed = game:GetService("ReplicatedStorage").Profiles[cha.Name].Inventory.Items.Doughnut
        foodValue = Items.Doughnut.Count.Value
    elseif Items:FindFirstChild("CakeSlice") and Items.CakeSlice.Count.Value > 0 then
        foodToFeed = game:GetService("ReplicatedStorage").Profiles[cha.Name].Inventory.Items.CakeSlice
        foodValue = Items.CakeSlice.Count.Value
    elseif Items:FindFirstChild("Sundae") and Items.Sundae.Count.Value > 0 then
        foodToFeed = game:GetService("ReplicatedStorage").Profiles[cha.Name].Inventory.Items.Sundae
        foodValue = Items.Sundae.Count.Value
    end
    return foodToFeed, foodValue
end

function upgradeEquip()
    if not CharProfileCheck or not CharProfileCheck:FindFirstChild('Equip') then return end
    for i,v in pairs(CharProfileCheck.Equip:GetDescendants()) do
        if v:FindFirstChild('UpgradeLimit') and v:FindFirstChild('Upgrade') then
            local upgrade_Left = v.UpgradeLimit.Value - v.Upgrade.Value
            if upgrade_Left ~= 0 then
                pcall(function()
                    game:GetService("ReplicatedStorage").Shared.ItemUpgrade.Upgrade:FireServer(v)
                end)
            end
        end
        if v:FindFirstChild('UpgradeLimit') and not v:FindFirstChild('Upgrade') then
            pcall(function()
                game:GetService("ReplicatedStorage").Shared.ItemUpgrade.Upgrade:FireServer(v)
            end)
        end
    end
    wait(.1)
end

-- autosell
function getItemList()
    local itemList = {}
    for a,b in pairs(require(game:GetService("ReplicatedStorage").Shared.Items)) do
        for i,v in pairs(b) do
            if (i == 'Type') and (v == 'Weapon' or v == 'Armor') then
                table.insert(itemList, b)
            end
        end
    end
    return itemList
end

function getItemName()
    itemNameTable = {}
    for i,v in ipairs(game:GetService("ReplicatedStorage").Profiles[cha.Name].Inventory.Items:GetChildren()) do
        if v:FindFirstChild('Level') or v:FindFirstChild('Upgrade') or v:FindFirstChild('UpgradeLimit') then
            if not string.find(v.Name:lower(), "pet") then
                table.insert(itemNameTable, v)
            end
        end
    end
    return itemNameTable
end

function ToSell()
    local itemToSell = {}
    local itemTypeTable = getItemList()
    local itemNameTable = getItemName()
    for _, item in ipairs(itemNameTable) do
        local itemName = (type(item) == 'table' and item.Name) or tostring(item)
        for _, t in ipairs(itemTypeTable) do
            if t and t.Name == itemName then
                local rarity = (t and t.Rarity)
                if rarity then
                    if getgenv().Common and rarity == 1 then table.insert(itemToSell, item) end
                    if getgenv().Uncommon and rarity == 2 then table.insert(itemToSell, item) end
                    if getgenv().Rare and rarity == 3 then table.insert(itemToSell, item) end
                    if getgenv().Epic and rarity == 4 then table.insert(itemToSell, item) end
                end
            end
        end
    end
    return itemToSell
end

function Selling()
    itemToSell = ToSell()
    if #itemToSell > 0 then
        game:GetService("ReplicatedStorage").Shared.Drops.SellItems:InvokeServer(itemToSell)
    end
end

-- coin magnet
spawn(function()
	while true do
		if getgenv().coin then
			for i,v in pairs(game.Workspace.Coins:GetChildren()) do
				if v.Name == 'CoinPart' then
                    repeat
                        pcall(function()
                            v.CanCollide = false
                            v.CFrame = plr.CFrame
                        end)
                        wait()
                    until not v:FindFirstChild('CoinPart') or not getgenv().coin
				end
			end
		end
		wait(0.5)
	end
end)

-- kill aura
spawn(function()
    while true do
        if getgenv().kill then
            mob, pos = monster()
            if #mob > 0 and #pos > 0 then
                for i,c in pairs(Classes[ClassGUI.Value] or {}) do
                    mob, pos = monster()
                    if getgenv().kill and #mob > 0 and #pos > 0 then
                        if Combat and Combat.AttackTargets then
                            pcall(function() Combat.AttackTargets(nil, mob, pos, c) end)
                        end
                        wait(.2)
                    end
                    if game and game.RunService and game.RunService.Heartbeat then
                        game.RunService.Heartbeat:Wait()
                    end
                end
            end 
        end
        wait(3.5)--getgenv().dalay
    end
end)

-- auto chest
game:GetService("CoreGui").PurchasePromptApp.Enabled = false
spawn(function()
    while true do
        if getgenv().chest then
            for i,v in pairs(game.Workspace:GetChildren()) do
                if v:IsA('Model') and string.find(v.Name:lower(), 'chest') then
                    pcall(function()
                        v.PrimaryPart.CFrame = plr.CFrame
                    end)
                    wait(.1)
                end
            end
        end
        wait(.5)
    end
end)

-- auto feed pet
spawn(function()
    while true do
        if getgenv().feedPet then
            repeat
                local food, foodValue = getFood()
                game:GetService("ReplicatedStorage").Shared.Pets.FeedPet:FireServer(food, true)
                game:GetService("RunService").Heartbeat:Wait()
            until not getgenv().feedPet
            wait(.1)
        end
        wait(0.5)
    end
end)

spawn(function()
    while true do
        if getgenv().upgrade then
            spawn(upgradeEquip)
        end
        wait(.25)
    end
end)

-- remove damage
game:GetService("Workspace").ChildAdded:Connect(function(v)
	if getgenv().damage then
		if v.Name == 'DamageNumber' then
			v:Destroy()
		end
	end
end)

-- skip cutscence (guarded)
local Camera = safeRequire(game.ReplicatedStorage and game.ReplicatedStorage.Client and game.ReplicatedStorage.Client.Camera) or { SkipCutscene = function() end }
if player and player.PlayerGui and player.PlayerGui:FindFirstChild('CutsceneUI') then
    local cut = player.PlayerGui.CutsceneUI
    if cut.Changed and cut.Changed.Connect then
        cut.Changed:Connect(function(v)
            if getgenv().skip then
                pcall(function() Camera:SkipCutscene() end)
            end
        end)
    end
end

-- Safely load UI library; fall back to a minimal no-op stub when network or pastebin is unavailable
local library
do
    -- remote UI loader disabled; prefer bundled/noop library to avoid executing network code
    local ok, lib = false, nil
    do end
    if ok and lib then
        library = lib
    else
        library = {}
        function library:CreateWindow(title)
            local win = {}
        function win:CreateFolder(name)
            local folder = {}
            function folder:Toggle(name, callback, ...) if type(callback) == 'function' then folder._lastToggle = callback end end
            function folder:Slider(name, min, max, whole, callback, ...) if type(callback) == 'function' then folder._lastSlider = callback end end
            function folder:Button(name, callback, ...) if type(callback) == 'function' then folder._lastButton = callback end end
            function folder:Label(text, opts) end
            function folder:Bind(name, key, callback, ...) if type(callback) == 'function' then folder._lastBind = callback end end
            function folder:GuiSettings(...) end
            function folder:CreateFolder() return folder end
            return folder
            end
            return win
        end
    end
end
local Game = library:CreateWindow("Game") -- Creates the window
local Combat = Game:CreateFolder("Combat")
local Misc = Game:CreateFolder("Misc")

local Other = library:CreateWindow("Other")
local SellItem = Other:CreateFolder("Auto Sell")
local OtherSetting = Other:CreateFolder("Player")

local Misc2 = library:CreateWindow("Misc")
local GUIS = Misc2:CreateFolder("Open Guis")
local Lobbies = Misc2:CreateFolder("Teleports")

local UI = library:CreateWindow("UI Settings")
local Setting = UI:CreateFolder("Settings")
local Credit = UI:CreateFolder("Credit")
local Update = UI:CreateFolder("Latest Updated")

-- Combat -- 
-- Kill aura
Combat:Toggle("Kill Aura",function(bool) 
    getgenv().kill = bool
end)

-- PvP
Combat:Toggle("PvP Arena",function(bool) 
    getgenv().killPlayer = bool
end)

-- Range
Combat:Slider("Range", 0, 10000, false,function(value)
    getgenv().range = value
end)

-- Delay
Combat:Slider("Delay", 3.5, 5, true, function(value)
    getgenv().dalay = 3.5
end)

-- Coin Magnet
Misc:Toggle("Coin Magnet",function(bool)
    getgenv().coin = bool
end)

-- Auto Chest
Misc:Toggle("Auto Chest",function(bool)
    getgenv().chest = bool
end)

-- Auto Feed Pet
Misc:Toggle("Auto Feed Pet",function(bool)
    getgenv().feedPet = bool
end)

-- Remove Damage
Misc:Toggle("Remove Damage",function(bool)
    getgenv().damage = bool
end)

-- Remove Effects
Misc:Toggle("Remove Effects",function(bool)
    getgenv().effect = bool
    effect = require(game:GetService("ReplicatedStorage").Shared.Effects)
    if bool then
        effect.RENDER_DISTANCE = 0
    else
        effect.RENDER_DISTANCE = 200
    end
end)


-- Fast Upgrade
Misc:Toggle("Fast Upgrade",function(bool)
    getgenv().upgrade = bool
end)

-- Skip Cutscenes
Misc:Toggle("Skip Cutscenes",function(bool)
    getgenv().skip = bool
end)

-- Auto Restart (persist to Menu when available)
Misc:Toggle("Auto Restart", function(bool)
    -- persist to getgenv-style Settings so modules that read _genv will pick it up
    if type(getgenv) == 'function' then
        local ok, g = pcall(getgenv)
        if ok and type(g) == 'table' then
            g.Settings = g.Settings or {}
            g.Settings.AutoRejoin = g.Settings.AutoRejoin or {}
            g.Settings.AutoRejoin.Enabled = bool
        end
    else
        _G.Settings = _G.Settings or {}
        _G.Settings.AutoRejoin = _G.Settings.AutoRejoin or {}
        _G.Settings.AutoRejoin.Enabled = bool
    end

    -- also try to persist into the shared Menu module if present in ReplicatedStorage
    pcall(function()
        local rs = game:GetService('ReplicatedStorage')
        if rs:FindFirstChild('Features') and rs.Features:FindFirstChild('Menu') then
            local Menu = require(rs.Features.Menu)
            if type(Menu.set) == 'function' then
                pcall(function() Menu.set('Settings.AutoRejoin.Enabled', bool) end)
            end
        end
    end)
end)

-- Other
-- Auto Sell
SellItem:Toggle("Common",function(bool)
    getgenv().Common = bool
end)

SellItem:Toggle("Uncommon",function(bool)
    getgenv().Uncommon = bool
end)

SellItem:Toggle("Rare",function(bool)
    getgenv().Rare = bool
end)

SellItem:Toggle("Epic",function(bool)
    getgenv().Epic = bool
end)

-- SellItem:Toggle("Legendary",function(bool)
--     getgenv().Legendary = bool
-- end)

SellItem:Button("Sell",function()
    Selling()
end)

-- Player
OtherSetting:Slider("Sprint", 28, 500, false,function(value)
    getgenv().sprint = value
    st.SPRINT_WALKSPEED = getgenv().sprint
end)

OtherSetting:Slider("Jump", 70, 500, false,function(value)
    getgenv().jump = value
    hum.JumpPower = getgenv().jump
end)

-- Lobbies --
Lobbies:Button("World 1",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(13)
end)

Lobbies:Button("World 2",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(19)
end)

Lobbies:Button("World 3",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(20)
end)

Lobbies:Button("World 4",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(29)
end)

Lobbies:Button("World 5",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(31)
end)

Lobbies:Button("World 6",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(36)
end)

Lobbies:Button("World 7",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(40)
end)

Lobbies:Button("PvP Arena",function()
    game.ReplicatedStorage.Shared.Teleport.TeleportToHub:FireServer(39)
end)


-- GUIS --
-- Open Sell
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
local hideTable = {
    ['RobloxGui'] = true,
    ['CoreScriptLocalization'] = true,
    ['TeleportGui'] = true,
    ['RobloxPromptGui'] = true,
    ['PurchasePromptApp'] = true,
    ['RobloxNetworkPauseNotification'] = true,
    ['TopBar'] = true
}

Setting:Bind("GUI Toggle",Enum.KeyCode.LeftAlt,function() -- LeftCtrl
    for i,v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if not hideTable[v.Name] then
            if v.Enabled then
                v.Enabled = false
            else
                v.Enabled = true
            end
        end
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
