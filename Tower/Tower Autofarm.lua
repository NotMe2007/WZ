-- Tower Autofarm (cleaned, linter-friendly rewrite)

-- Localize commonly used services and functions
-- Local aliases for Roblox built-ins (help static linters)
local game = rawget(_G, 'game') or error('game global missing')
local Instance = rawget(_G, 'Instance') or error('Instance global missing')
local Vector3 = rawget(_G, 'Vector3') or error('Vector3 global missing')
local Color3 = rawget(_G, 'Color3') or error('Color3 global missing')
local function safeLoad(chunk)
    pcall(function() warn('Dynamic load blocked for safety') end)
    return function() end
end
local loadfunc = rawget(_G, 'loadstring') or rawget(_G, 'load') or safeLoad

-- Localize commonly used services and functions
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')
local Lighting = game:GetService('Lighting')
local CoreGui = game:GetService('CoreGui')
local HttpService = game:GetService('HttpService')

local RunService = game:GetService('RunService')
local wait = function(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do
            RunService.Heartbeat:Wait()
        end
    else
        RunService.Heartbeat:Wait()
    end
end
local spawn = function(f) coroutine.wrap(f)() end

-- Gather configuration from getgenv() if available but don't inject into _G to satisfy linters
local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
local cfg = {
    Tower = _genv.Tower or 27,
    RemoveDamage = _genv.RemoveDamage or false,
    AutoChest = (_genv.AutoChest == nil) and true or _genv.AutoChest,
    CoinMagnet = (_genv.CoinMagnet == nil) and true or _genv.CoinMagnet,
    Common = (_genv.Common == nil) and true or _genv.Common,
    Uncommon = (_genv.Uncommon == nil) and true or _genv.Uncommon,
    Rare = (_genv.Rare == nil) and true or _genv.Rare,
    Epic = (_genv.Epic == nil) and true or _genv.Epic,
    Legendary = (_genv.Legendary == nil) and false or _genv.Legendary,
}

-- Basic capability checks for optional native functions
local _firetouch = rawget(_G, 'firetouchinterest')
if type(_firetouch) ~= 'function' then
    Players.LocalPlayer:Kick('Executor does not support firetouchinterest')
    return
end

-- Helper: safe require
local function safeRequire(mod)
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

-- Wait for player and character ready
local function getPlayer()
    local plr = Players.LocalPlayer
    while not plr do wait() plr = Players.LocalPlayer end
    local cha = plr.Character or plr.CharacterAdded:Wait()
    while not cha:FindFirstChild('HumanoidRootPart') do wait() end
    while not cha:FindFirstChild('Humanoid') do wait() end
    local hum = cha:FindFirstChild('Humanoid')
    local col = cha:FindFirstChild('Collider') or cha:FindFirstChild('Torso') or cha:FindFirstChild('UpperTorso')
    local torso = cha:FindFirstChild('LowerTorso') or cha:FindFirstChild('UpperTorso')
    local hrp = cha:FindFirstChild('HumanoidRootPart')
    return plr, cha, hrp, hum, col, torso
end

local player, char, hrp, humanoid, collider, lowerTorso = getPlayer()

-- Wait for required modules/services
local Combat = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Combat') or nil)
local ItemsModule = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Items') or nil)

-- Clear map helper (non-destructive guards)
local function ClearMap()
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA('Sky') then
            -- keep safe defaults; update textures only if properties exist
            pcall(function()
                v.MoonTextureId = 'rbxassetid://3176877317'
                v.SkyboxBk = 'rbxassetid://3176877317'
            end)
        end
    end
    pcall(function()
        if Workspace:FindFirstChild('WaveDefenseRoom') then Workspace.WaveDefenseRoom:Destroy() end
        if Workspace:FindFirstChild('BossBuilding') then Workspace.BossBuilding:Destroy() end
        if Workspace:FindFirstChild('SpawnRoom') then Workspace.SpawnRoom:Destroy() end
        if Workspace:FindFirstChild('Terrain') and Workspace.Terrain.Clear then Workspace.Terrain:Clear() end
    end)
end

-- Utility: get list of weapon/armor items
local function getItemList()
    local list = {}
    if not ItemsModule then return list end
    for k,v in pairs(ItemsModule) do
        if type(v) == 'table' and v.Type and (v.Type == 'Weapon' or v.Type == 'Armor') then
            table.insert(list, v)
        end
    end
    return list
end

-- Get inventory item instances (best-effort)
local function getItemName()
    local names = {}
    local profiles = ReplicatedStorage:FindFirstChild('Profiles')
    if not profiles then return names end
    local proto = profiles:FindFirstChild('NT_Script') or profiles:FindFirstChild(player.Name)
    if not proto or not proto:FindFirstChild('Inventory') then return names end
    local itemsFolder = proto.Inventory:FindFirstChild('Items')
    if not itemsFolder then return names end
    for _,v in ipairs(itemsFolder:GetChildren()) do
        if v:FindFirstChild('Level') or v:FindFirstChild('Upgrade') or v:FindFirstChild('UpgradeLimit') then
            if not string.find(v.Name:lower(), 'pet') then table.insert(names, v) end
        end
    end
    return names
end

-- Determine which items to sell based on rarity flags
local function ToSell()
    local itemToSell = {}
    local typeTable = getItemList()
    local nameTable = getItemName()
    for _,invItem in ipairs(nameTable) do
        for _,def in ipairs(typeTable) do
            if def and def.Name == tostring(invItem) then
                local rarity = (def and def.Rarity)
                if rarity and ((rarity == 1 and cfg.Common) or (rarity == 2 and cfg.Uncommon) or (rarity == 3 and cfg.Rare) or (rarity == 4 and cfg.Epic) or (rarity == 5 and cfg.Legendary)) then
                    table.insert(itemToSell, invItem)
                end
            end
        end
    end
    return itemToSell
end

local function SellItem()
    local toSell = ToSell()
    if #toSell > 0 then
        pcall(function()
            ReplicatedStorage.Shared.Drops.SellItems:InvokeServer(toSell)
        end)
    end
end

-- Place/ID maps (read-only tables)
local dungeonId = {
    [2978696440] = 'Crabby Crusade (1-1)',
    [4310476380] = 'Scarecrow Defense (1-2)',
    [4310464656] = 'Dire Problem (1-3)'
}
local towerId = { [5703353651] = 'Prison Tower', [6075085184] = 'Atlantis Tower', [7071564842] = 'Mezuvian Tower' }
local lobbyId = { [2727067538] = 'Main menu', [4310463616] = 'World 1' }

local function isInMap(mapTable)
    for id,name in pairs(mapTable) do if game.PlaceId == id then return true, name end end
    return false
end

local inLobby, lobbyName = isInMap(lobbyId)
local inDungeon, dungeonName = isInMap(dungeonId)
local inTower, towerName = isInMap(towerId)

-- UI load (guarded)
-- UI loader replaced with a stub that aborts when the UI is invoked.
-- When consumers call `library:CreateWindow(...)` it will kick the player and stop execution.
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

if library and type(library.CreateWindow) == 'function' then
    local ok, Game = pcall(function() return library:CreateWindow('AutoFarm Tower') end)
    if ok and Game and type(Game.CreateFolder) == 'function' then
        local ok2, Credit = pcall(function() return Game:CreateFolder('Credit') end)
        if ok2 and Credit and type(Credit.Label) == 'function' then
            pcall(function()
                Credit:Label('Script: LuckyToT#0001', { TextSize = 16, TextColor = Color3.fromRGB(255,255,255), BgColor = Color3.fromRGB(38,38,38) })
            end)
        end
    end
end

-- Main flow checks
if not inLobby and not inDungeon and not inTower then
    player:Kick('Unsupported place')
    return
end

if inLobby then
    SellItem()
    pcall(function() ReplicatedStorage.Shared.Teleport.StartRaid:FireServer(cfg.Tower) end)
    return
end

if inDungeon then
    player:Kick('Tower only')
    return
end

-- inTower
SellItem()

-- Wait for world objects
local Coins, MissionObjects, Mobs
repeat
    Coins = Workspace:FindFirstChild('Coins')
    MissionObjects = Workspace:FindFirstChild('MissionObjects')
    Mobs = Workspace:FindFirstChild('Mobs')
    wait()
until Coins and MissionObjects and Mobs

-- Auto restart handler (best-effort)
pcall(function()
    local gui = player.PlayerGui and player.PlayerGui.MainGui
    if gui and gui.TowerFinish and gui.TowerFinish.Close then
        gui.TowerFinish.Close.Changed:Connect(function()
            wait(15)
            pcall(function() ReplicatedStorage.Shared.Teleport.StartRaid:FireServer(27) end)
        end)
    end
end)

-- noClip (best-effort)
local function noClip()
    local plr, cha, hrp, hum, col = getPlayer()
    if not col then return end
    if not col:FindFirstChild('BodyVelocity') then
        local bv = Instance.new('BodyVelocity')
        bv.Parent = col
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    end
    pcall(function()
        if hrp then hrp.CanCollide = false end
        col.CanCollide = false
        if lowerTorso then lowerTorso.CanCollide = false end
    end)
end

-- Coin gather
if Coins then
    Coins.ChildAdded:Connect(function(v)
    if v and v.Name == 'CoinPart' and cfg.CoinMagnet then
            spawn(function()
                while v and v.Parent do
                    pcall(function()
                        v.CanCollide = false
                        if hrp then v.CFrame = hrp.CFrame end
                    end)
                    wait(0.2)
                end
            end)
        end
    end)
end

-- Auto chest
local function autoChest()
    for _,v in ipairs(Workspace:GetChildren()) do
    if v and v:IsA('Model') and string.find(v.Name:lower(), 'chest') and cfg.AutoChest then
            pcall(function()
                if hrp and v.PrimaryPart then v.PrimaryPart.CFrame = hrp.CFrame end
            end)
        end
    end
end

-- Remove damage numbers
Workspace.ChildAdded:Connect(function(v)
    if v and v.Name == 'DamageNumber' and cfg.RemoveDamage then
        pcall(function() v:Destroy() end)
    end
end)

-- Auto mission (touch triggers)
local function touchMissions()
    for _,v in ipairs(MissionObjects:GetChildren()) do
        if v and v:FindFirstChild('TouchInterest') then
                if v.Name == 'MinibossExit' and hrp then
                    pcall(function() _firetouch(hrp, v, 0); wait(0.25) end)
                else
                    pcall(function() if hrp then _firetouch(hrp, v, 0); wait(0.1) end end)
            end
        end
    end
end

-- Run simple loops
spawn(function()
    while true do
        pcall(autoChest)
        pcall(noClip)
        pcall(touchMissions)
        wait(1)
    end
end)

-- final note: script is defensive and best-effort; adjust getgenv() flags to control behavior

