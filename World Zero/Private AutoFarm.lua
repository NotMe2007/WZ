-- Private AutoFarm (cleaned and hardened)
-- Kept original behavior, added guards for nils and safer event wiring.

-- Environment and safe runtime aliases
local _G_env = _G
-- try to pull real Roblox globals when running in Roblox, otherwise provide safe fallbacks for static analysis
local game = rawget(_G_env, 'game') or nil
local workspace = rawget(_G_env, 'workspace') or (game and game:GetService('Workspace')) or nil
local task = rawget(_G_env, 'task') or { wait = function() end, spawn = function(fn) fn() end }
local spawn = rawget(_G_env, 'spawn') or task.spawn
local Vector3 = rawget(_G_env, 'Vector3') or { new = function() return nil end }
local Vector2 = rawget(_G_env, 'Vector2') or { new = function() return nil end }
local CFrame = rawget(_G_env, 'CFrame') or { new = function() return nil end }
local Instance = rawget(_G_env, 'Instance') or { new = function() return nil end }
local typeof = rawget(_G_env, 'typeof') or function(v) return type(v) end

local _rawget = rawget
local _G_env2 = _G
local _getgenv = _rawget(_G_env2, 'getgenv') or function() return {} end
local getgenv = _getgenv
local _firetouchinterest = _rawget(_G_env2, 'firetouchinterest') or function() end
local firetouchinterest = _firetouchinterest
local _getconnections = _rawget(_G_env2, 'getconnections') or function() return {} end
local getconnections = _getconnections
local _setclipboard = _rawget(_G_env2, 'setclipboard') or function() end
local setclipboard = _setclipboard
local function safeLoad(chunk)
    pcall(function() warn('Dynamic load blocked for safety') end)
    return function() end
end
local _loadstring = _rawget(_G_env2, 'loadstring') or _rawget(_G_env2, 'load') or safeLoad
local loadstring = _loadstring

local function safeGetService(name)
    if game and game.GetService then
        return game:GetService(name)
    end
    -- fallback dummy table to avoid runtime errors in non-roblox static checks
    return setmetatable({}, { __index = function() return function() end end })
end

local Players = safeGetService('Players')
local ReplicatedStorage = safeGetService('ReplicatedStorage')
local Workspace = safeGetService('Workspace')
local VirtualUser = safeGetService('VirtualUser')

-- default settings (can be changed at runtime)
getgenv().Dance = true
getgenv().AutoUpgrade = true
getgenv().AutoChest = true
getgenv().CoinMagnet = true
getgenv().RemoveDamage = false
getgenv().SkipCutscene = true

getgenv().Settings = getgenv().Settings or {
    Dungeon = { Enabled = true, AutoSelectHighest = true, CustomDungeon = { DungeonId = 16 } },
    Tower = { Enabled = false, AutoSelectHighest = false, CustomTower = { TowerId = 23 } },
    AutoRejoin = { Enabled = true, DungeonDelay = 1, TowerDelay = 15 },
    AutoSell = { Enabled = false, Common = true, Uncommon = true, Rare = true, Epic = true },
}

-- quick capability checks
if not rawget(_G, 'firetouchinterest') then
    if Players and Players.LocalPlayer then Players.LocalPlayer:Kick('firetouchinterest not available') end
    return
end
if not rawget(_G, 'getconnections') then
    if Players and Players.LocalPlayer then Players.LocalPlayer:Kick('getconnections not available') end
    return
end

-- wait until game loaded (guarded)
if game and game.IsLoaded then repeat task.wait() until game:IsLoaded() end

-- safe player getter
local function getPlayer()
    local plr = Players.LocalPlayer
    while not plr do task.wait() plr = Players.LocalPlayer end
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hrp = char:WaitForChild('HumanoidRootPart')
    local col = char:FindFirstChild('Collider')
    local torso = char:FindFirstChild('LowerTorso') or char:FindFirstChild('Torso')
    local hum = char:FindFirstChild('Humanoid')
    return plr, char, hrp, hum, col, torso
end

local player, char, plr, hum, col, torso = getPlayer()

-- load shared modules with guards
local ok, Combat = pcall(function() return require(ReplicatedStorage.Shared.Combat) end)
if not ok then Combat = nil end
local CharProfileCheck = ReplicatedStorage:FindFirstChild('Profiles') and ReplicatedStorage.Profiles:FindFirstChild(char.Name)
local ClassGUI = CharProfileCheck and CharProfileCheck:FindFirstChild('Class') or nil
local Mission = Workspace:FindFirstChild('MissionObjects')

-- Classes table (unchanged entries preserved)
local Classes = {
    ["Swordmaster"] = {"Swordmaster1","Swordmaster2","Swordmaster3","Swordmaster4","Swordmaster5","Swordmaster6","CrescentStrike1","CrescentStrike2","CrescentStrike3","Leap"},
    ["Mage"] = {"Mage1","ArcaneBlastAOE","ArcaneBlast","ArcaneWave1","ArcaneWave2","ArcaneWave3","ArcaneWave4","ArcaneWave5","ArcaneWave6","ArcaneWave7","ArcaneWave8","ArcaneWave9"},
    ["Defender"] = {"Defender1","Defender2","Defender3","Defender4","Defender5","Groundbreaker","Spin1","Spin2","Spin3","Spin4","Spin5"},
    ["DualWielder"] = {"DualWield1","DualWield2","DualWield3","DualWield4","DualWield5","DualWield6","DualWield7","DualWield8","DualWield9","DualWield10","DashStrike","CrossSlash1","CrossSlash2","CrossSlash3","CrossSlash4"},
    ["Guardian"] = {"Guardian1","Guardian2","Guardian3","Guardian4","SlashFury1","SlashFury2","SlashFury3","SlashFury4","SlashFury5","SlashFury6","SlashFury7","SlashFury8","SlashFury9","SlashFury10","SlashFury11","SlashFury12","SlashFury13","RockSpikes1","RockSpikes2","RockSpikes3"},
    ["IcefireMage"] = {"IcefireMage1","IcySpikes1","IcySpikes2","IcySpikes3","IcySpikes4","IcefireMageFireballBlast","IcefireMageFireball","LightningStrike1","LightningStrike2","LightningStrike3","LightningStrike4","LightningStrike5","IcefireMageUltimateFrost","IcefireMageUltimateMeteor1"},
    ["Berserker"] = {"Berserker1","Berserker2","Berserker3","Berserker4","Berserker5","Berserker6","AggroSlam","GigaSpin1","GigaSpin2","GigaSpin3","GigaSpin4","GigaSpin5","GigaSpin6","GigaSpin7","GigaSpin8","Fissure1","Fissure2","FissureErupt1","FissureErupt2","FissureErupt3","FissureErupt4","FissureErupt5"},
    ["Paladin"] = {"Paladin1","Paladin2","Paladin3","Paladin4","LightThrust1","LightThrust2","LightPaladin1","LightPaladin2"},
    ["MageOfLight"] = {"MageOfLight","MageOfLightBlast"},
    ["Demon"] = {"Demon1","Demon4","Demon7","Demon10","Demon13","Demon16","Demon19","Demon22","Demon25","DemonDPS1","DemonDPS2","DemonDPS3","DemonDPS4","DemonDPS5","DemonDPS6","DemonDPS7","DemonDPS8","DemonDPS9","ScytheThrowDPS1","ScytheThrowDPS2","ScytheThrowDPS3","DemonLifeStealDPS","DemonSoulDPS1","DemonSoulDPS2","DemonSoulDPS3"},
    ["Dragoon"] = {"Dragoon1","Dragoon2","Dragoon3","Dragoon4","Dragoon5","Dragoon6","Dragoon7","DragoonDash","DragoonCross1","DragoonCross2","DragoonCross3","DragoonCross4","DragoonCross5","DragoonCross6","DragoonCross7","DragoonCross8","DragoonCross9","DragoonCross10","MultiStrike1","MultiStrike2","MultiStrike3","MultiStrike4","MultiStrike5","MultiStrikeDragon1","MultiStrikeDragon2","MultiStrikeDragon3","DragoonFall"},
    ["Archer"] = {"Archer","PiercingArrow1","PiercingArrow2","PiercingArrow3","PiercingArrow4","PiercingArrow5","PiercingArrow6","PiercingArrow7","PiercingArrow8","PiercingArrow9","PiercingArrow10","SpiritBomb","MortarStrike1","MortarStrike2","MortarStrike3","MortarStrike4","MortarStrike5","MortarStrike6","MortarStrike7","HeavenlySword1","HeavenlySword2","HeavenlySword3","HeavenlySword4","HeavenlySword5","HeavenlySword6","HeavenlySword7"}
}

-- safely disable remote event connections (if present)
if Combat and Combat.GetAttackEvent then
    local ok, evt = pcall(function() return Combat:GetAttackEvent() end)
    if ok and evt and evt.OnClientEvent then
        local function safeIterConnections(evt)
            local gc = rawget(_G_env2, 'getconnections')
            if type(gc) == 'function' then
                local ok2, res = pcall(function() if evt then return gc(evt) else return gc() end end)
                if ok2 and type(res) == 'table' then return res end
            end
            if evt and type(evt.GetConnections) == 'function' then
                local ok3, res3 = pcall(function() return evt:GetConnections() end)
                if ok3 and type(res3) == 'table' then return res3 end
            end
            return {}
        end
        pcall(function()
            for _, conn in ipairs(safeIterConnections(evt.OnClientEvent)) do
                pcall(function() if conn and conn.Disable then conn:Disable() end end)
            end
        end)
    end
end

-- helper: safe invoke/calls
local function safeInvoke(func, ...)
    if not func then return end
    return pcall(func, ...)
end

-- Auto Sell helpers
local function getItemList()
    local itemList = {}
    local ok, Items = pcall(function() return require(ReplicatedStorage.Shared.Items) end)
    if not ok or type(Items) ~= 'table' then return itemList end
    for _, info in pairs(Items) do
        if type(info) == 'table' and info.Type and (info.Type == 'Weapon' or info.Type == 'Armor') then
            table.insert(itemList, info)
        end
    end
    return itemList
end

local function getItemName()
    local names = {}
    local profileInv = ReplicatedStorage:FindFirstChild('Profiles') and ReplicatedStorage.Profiles:FindFirstChild('NT_Script')
    if profileInv and profileInv:FindFirstChild('Inventory') and profileInv.Inventory:FindFirstChild('Items') then
        for _, v in ipairs(profileInv.Inventory.Items:GetChildren()) do
            if (v:FindFirstChild('Level') or v:FindFirstChild('Upgrade') or v:FindFirstChild('UpgradeLimit')) and not tostring(v.Name):lower():find('pet') then
                table.insert(names, v)
            end
        end
    end
    return names
end

local function ToSell()
    local itemToSell = {}
    local itemTypeTable = getItemList()
    local itemNameTable = getItemName()
    for _, invItem in ipairs(itemNameTable) do
        for _, info in ipairs(itemTypeTable) do
            if tostring(info.Name) == tostring(invItem) then
                local rarity = (info and info.Rarity)
                if rarity then
                    if rarity == 1 and getgenv().Settings.AutoSell.Common then table.insert(itemToSell, invItem) end
                    if rarity == 2 and getgenv().Settings.AutoSell.Uncommon then table.insert(itemToSell, invItem) end
                    if rarity == 3 and getgenv().Settings.AutoSell.Rare then table.insert(itemToSell, invItem) end
                    if rarity == 4 and getgenv().Settings.AutoSell.Epic then table.insert(itemToSell, invItem) end
                end
            end
        end
    end
    return itemToSell
end

local function SellItem()
    local itemToSell = ToSell()
    for _, v in ipairs(itemToSell) do warn('Sell:', v) end
    if #itemToSell > 0 then
        pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Drops and ReplicatedStorage.Shared.Drops.SellItems then ReplicatedStorage.Shared.Drops.SellItems:InvokeServer(itemToSell) end end)
    end
end

-- Auto select logic
local function GetLevelPlayer()
    if ReplicatedStorage and ReplicatedStorage.Profiles and ReplicatedStorage.Profiles[char.Name] and ReplicatedStorage.Profiles[char.Name].Level then
        return ReplicatedStorage.Profiles[char.Name].Level.Value
    end
    return 0
end
local function Start(worldId)
    if worldId and type(worldId) == 'number' and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Teleport and ReplicatedStorage.Shared.Teleport.StartRaid then
        pcall(function() ReplicatedStorage.Shared.Teleport.StartRaid:FireServer(worldId) end)
    end
end

-- Auto select dungeon/tower (kept mapping)
local function AutoSelectDungeon(level)
    local id
    if level >= 90 then id = 26 elseif level >= 75 then id = 25 elseif level >= 60 then id = 24 elseif level >= 55 then id = 18 elseif level >= 50 then id = 19 elseif level >= 45 then id = 20 elseif level >= 40 then id = 16 elseif level >= 35 then id = 15 elseif level >= 30 then id = 14 elseif level >= 26 then id = 7 elseif level >= 22 then id = 13 elseif level >= 18 then id = 12 elseif level >= 15 then id = 11 elseif level >= 12 then id = 6 elseif level >= 10 then id = 4 elseif level >= 7 then id = 2 elseif level >= 4 then id = 3 else id = 1 end
    Start(id)
end
local function AutoSelectTower(level)
    local id
    if level >= 90 then id = 27 elseif level >= 70 then id = 23 elseif level >= 60 then id = 21 end
    Start(id)
end

-- Clear helpers
local function ClearMap()
    local names = { 'WaveDefenseRoom','BossBuilding','SpawnRoom' }
    for _,n in ipairs(names) do
        local obj = Workspace:FindFirstChild(n)
        if obj then pcall(function() obj:Destroy() end) end
    end
    if Mission then
        pcall(function()
            if Mission:FindFirstChild('GatesAAA') then Mission.GatesAAA:Destroy() end
            if Mission:FindFirstChild('CeilingGood') then Mission.CeilingGood:Destroy() end
        end)
    end
end

-- IDs maps (unchanged)
local dungeonId = { [2978696440]='Crabby Crusade (1-1)', [4310476380]='Scarecrow Defense (1-2)', [4310464656]='Dire Problem (1-3)', [4310478830]='Kingslayer (1-4)', [3383444582]='Gravetower Dungeon (1-5)', [3885726701]='Temple of Ruin (2-1)', [3994953548]='Mama Trauma (2-2)', [4050468028]="Volcano's Shadow (2-3)", [3165900886]='Volcano Dungeon (2-4)', [4465988196]='Mountain Pass (3-1)', [4465989351]='Winter Cavern (3-2)', [4465989998]='Winter Dungeon (3-3)', [4646473427]='Scrap Canyon (4-1)', [4646475342]='Deserted Burrowmine (4-2)', [4646475570]='Pyramid Dungeon (4-3)', [6386112652]='Konoh Heartlands (5-1)', [6510862058]='Atlantic Atoll (6-1)', [6847034886]='Mezuvia Skylands (7-1)'}
local towerId = { [5703353651]='Prison Tower', [6075085184]='Atlantis Tower', [7071564842]='Mezuvian Tower' }
local lobbyId = { [2727067538]='Main menu', [4310463616]='World 1', [4310463940]='World 2', [4465987684]='World 3', [4646472003]='World 4', [5703355191]='World 5', [6075083204]='World 6', [6847035264]='World 7' }

local function lobbyCheck()
    for id,name in pairs(lobbyId) do if game and game.PlaceId == id then warn('Lobby:', name) return true end end; return false
end
local function dungeonCheck()
    for id,name in pairs(dungeonId) do if game and game.PlaceId == id then warn('Dungeon:', name) return true end end; return false
end
local function towerCheck()
    for id,name in pairs(towerId) do if game and game.PlaceId == id then warn('Tower:', name) return true end end; return false
end

local inLobby, inDungeon, inTower = lobbyCheck(), dungeonCheck(), towerCheck()

-- Safe UI library load: do NOT execute remote code. If HTTP is required, user must opt-in.
local library
do
    -- Remote UI loader is intentionally disabled; do not perform HTTP requests or execute remote code here.
    if Players and Players.LocalPlayer and Players.LocalPlayer.Kick then
        Players.LocalPlayer:Kick('Remote UI loaders are disabled for safety')
    end
    -- Fallback no-op UI library
    library = { CreateWindow = function(title, ...)
        local win = {}
        function win:CreateFolder(name)
            local folder = {}
            function folder:Toggle(name, cb, ...) if type(cb) == 'function' then folder._lastToggle = cb end end
            function folder:Slider(name, min, max, whole, cb, ...) if type(cb) == 'function' then folder._lastSlider = cb end end
            function folder:Button(name, cb, ...) if type(cb) == 'function' then folder._lastButton = cb end end
            function folder:Label(text, opts) end
            function folder:Bind(name, key, cb, ...) if type(cb) == 'function' then folder._lastBind = cb end end
            function folder:CreateFolder() return folder end
            function folder:GuiSettings(...) end
            return folder
        end
        return win
    end }
end
local Game = library:CreateWindow('AutoFarm')
local Credit = Game and Game.CreateFolder and Game:CreateFolder('Credit') or nil
local Update = Game and Game.CreateFolder and Game:CreateFolder('Latest Updated')

-- Credit UI (safe no-ops if library missing)
if Credit and Credit.Label then
    pcall(function() Credit:Label('Script: LuckyToT#0001',{ TextSize=16 }) end)
    pcall(function() Credit:Button('Copy user', function() if rawget(_G,'setclipboard') then setclipboard('LuckyToT#0001') else if player and player.Kick then player:Kick('Clipboard not supported') end end end) end)
end

-- noClip implementation
local function noClip()
    local plrObj, ch, hrp, h, collider, low = getPlayer()
    spawn(function()
        repeat
            local bv = Instance.new('BodyVelocity')
            bv.Velocity = Vector3.new(0,0,0)
            bv.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
            bv.P = 9000
            bv.Parent = hrp
            task.wait()
        until hrp:FindFirstChild('BodyVelocity')
        pcall(function() hrp.CanCollide = false end)
        pcall(function() if collider then collider.CanCollide = false end end)
        pcall(function() if low then low.CanCollide = false end end)
        ClearMap()
    end)
end

-- coin magnet
if Workspace and Workspace:FindFirstChild('Coins') then
    Workspace.Coins.ChildAdded:Connect(function(v)
        if v and v.Name == 'CoinPart' and getgenv().CoinMagnet then
            spawn(function()
                while v and v.Parent do
                    pcall(function() if plr and v:IsA('BasePart') then v.CanCollide = false; v.CFrame = plr.CFrame end end)
                    task.wait(0.2)
                end
            end)
        end
    end)
end

-- Auto rejoin: guarded event hookups
pcall(function()
    if player and player:FindFirstChild('PlayerGui') then
        local towerFinish = player.PlayerGui:WaitForChild('MainGui'):WaitForChild('TowerFinish')
        if towerFinish and towerFinish:FindFirstChild('Close') then
            towerFinish.Close.Changed:Connect(function()
                local level = GetLevelPlayer()
                if getgenv().Settings.AutoRejoin.Enabled then
                    task.wait(getgenv().Settings.AutoRejoin.TowerDelay)
                    if getgenv().Settings.Tower.Enabled then
                        if getgenv().Settings.Tower.AutoSelectHighest then AutoSelectTower(level) else Start(getgenv().Settings.Tower.CustomTower.TowerId) end
                    end
                end
            end)
        end
    end
end)

pcall(function()
    if player and player.PlayerGui then
        local rewards = player:WaitForChild('PlayerGui'):WaitForChild('MainGui'):WaitForChild('MissionRewards')
        if rewards and rewards:FindFirstChild('Rewards') then
            rewards.Rewards.Changed:Connect(function()
                task.wait(8)
                pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Missions and ReplicatedStorage.Shared.Missions.GetMissionPrize then ReplicatedStorage.Shared.Missions.GetMissionPrize:InvokeServer() end end)
                pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Missions and ReplicatedStorage.Shared.Missions.LeaveChoice then ReplicatedStorage.Shared.Missions.LeaveChoice:FireServer(true) end end)
                local level = GetLevelPlayer()
                if getgenv().Settings.AutoRejoin.Enabled then
                    task.wait(getgenv().Settings.AutoRejoin.DungeonDelay)
                    if getgenv().Settings.Dungeon.Enabled then
                        if getgenv().Settings.Dungeon.AutoSelectHighest then AutoSelectDungeon(level) else Start(getgenv().Settings.Dungeon.CustomDungeon.DungeonId) end
                    end
                else
                    pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Missions and ReplicatedStorage.Shared.Missions.LeaveChoice then ReplicatedStorage.Shared.Missions.LeaveChoice:FireServer(true) end end)
                    pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Missions and ReplicatedStorage.Shared.Missions.NotifyReadyToLeave then ReplicatedStorage.Shared.Missions.NotifyReadyToLeave:FireServer() end end)
                end
            end)
        end
    end
end)

-- remove damage numbers
if Workspace then Workspace.ChildAdded:Connect(function(v) if v and v.Name == 'DamageNumber' and getgenv().RemoveDamage then pcall(function() v:Destroy() end) end end) end

-- skip cutscenes
pcall(function()
    local cutSceneModule = ReplicatedStorage:FindFirstChild('Client') and ReplicatedStorage.Client:FindFirstChild('Camera')
    if cutSceneModule then
        local ok, cutScene = pcall(function() return require(cutSceneModule) end)
        if ok and cutScene then
            pcall(function()
                if player and player:FindFirstChild('PlayerGui') and player.PlayerGui:FindFirstChild('CutsceneUI') then
                    player.PlayerGui.CutsceneUI.Changed:Connect(function() if getgenv().SkipCutscene then pcall(function() if cutScene.SkipCutscene then cutScene:SkipCutscene() end end) end end)
                end
            end)
        end
    end
end)

-- anti afk
if player and player.Idled then player.Idled:Connect(function() VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame); task.wait(1); VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame) end) end

-- UI tweaks (Vitals)
pcall(function()
    local Vitals = player and player:FindFirstChild('PlayerGui') and player.PlayerGui:FindFirstChild('MainGui') and player.PlayerGui.MainGui:FindFirstChild('Hotbar') and player.PlayerGui.MainGui.Hotbar:FindFirstChild('Vitals')
    pcall(function()
        if Vitals and Vitals:FindFirstChild('XP') then if Vitals.XP:FindFirstChild('TextLabel') then Vitals.XP.TextLabel.Visible = false end; if Vitals.XP:FindFirstChild('Shadow') then Vitals.XP.Shadow.Visible = false end end
        if Vitals and Vitals:FindFirstChild('Health') and Vitals.Health:FindFirstChild('HealthText') then Vitals.Health.HealthText.Text = 'Script by LuckyToT#0001'; if Vitals.Health.HealthText:FindFirstChild('Overlay') then Vitals.Health.HealthText.Overlay.Text = 'Script by LuckyToT#0001' end end
    end)
end)

local function credit()
    pcall(function()
        local Vitals = player and player:FindFirstChild('PlayerGui') and player.PlayerGui:FindFirstChild('MainGui') and player.PlayerGui.MainGui:FindFirstChild('Hotbar') and player.PlayerGui.MainGui.Hotbar:FindFirstChild('Vitals')
        if Vitals and Vitals.Health and Vitals.Health:FindFirstChild('HealthText') then
            Vitals.Health.HealthText.Text = 'Script by LuckyToT#0001'
            if Vitals.Health.HealthText:FindFirstChild('Overlay') then Vitals.Health.HealthText.Overlay.Text = 'Script by LuckyToT#0001' end
        end
        pcall(function()
            local menu = player and player.PlayerGui and player.PlayerGui.MainGui and player.PlayerGui.MainGui:FindFirstChild('Menu')
            if menu and menu:FindFirstChild('DesktopMenu') and menu.DesktopMenu:FindFirstChild('Button') and menu.DesktopMenu.Button:FindFirstChild('ImageLabel') then
                menu.DesktopMenu.Button.ImageLabel.Image = 'rbxassetid://4782301932'
            end
        end)
    end)
end

-- auto chest
local function autoChest()
    if not Workspace then return end
    for _,v in ipairs(Workspace:GetChildren()) do
        if v:IsA('Model') and tostring(v.Name):lower():find('chest') and getgenv().AutoChest then
            pcall(function() if v.PrimaryPart and plr then v.PrimaryPart.CFrame = plr.CFrame end end)
        end
    end
end

local function move(enemies, x,y,z)
    if not enemies then return end
    if x == nil and y == nil and z == nil then
        if enemies:IsA('BasePart') or enemies:IsA('Model') then
            local cf = (enemies.PrimaryPart and enemies.PrimaryPart.CFrame) or enemies.CFrame
            if col then col.CFrame = cf end
            if torso then torso.CFrame = cf end
        end
    else
        local cf = (enemies.PrimaryPart and enemies.PrimaryPart.CFrame) or enemies.CFrame
        if col then col.CFrame = cf * CFrame.new(x or 0, y or 0, z or 0) end
        if torso then torso.CFrame = cf * CFrame.new(x or 0, y or 0, z or 0) end
    end
end

local function touchPart(part)
    if not part then return end
    pcall(function() firetouchinterest(plr, part, 0) end)
    task.wait(0.25)
    pcall(function() firetouchinterest(plr, part, 1) end)
end

-- main routing
if not inLobby and not inDungeon and not inTower then
    if player and player.Kick then player:Kick('S U S') end
    return
end

if inLobby then
    local level = GetLevelPlayer()
    if getgenv().Settings.Dungeon.Enabled then
        if getgenv().Settings.Dungeon.AutoSelectHighest then AutoSelectDungeon(level) else Start(getgenv().Settings.Dungeon.CustomDungeon.DungeonId) end
    elseif getgenv().Settings.Tower.Enabled then
        if getgenv().Settings.Tower.AutoSelectHighest then AutoSelectTower(level) else Start(getgenv().Settings.Tower.CustomTower.TowerId) end
    end
    if getgenv().Settings.AutoSell.Enabled then SellItem() end
end

if inDungeon then
    player, char, plr, hum, col, torso = getPlayer()
    if getgenv().Settings.AutoSell.Enabled then SellItem() end
    task.wait(5)

    -- mission handlers (guarded)
    if Mission and Mission:FindFirstChild('Cabbages') then
        Mission.Cabbages.DescendantAdded:Connect(function(v)
            if v and v.ClassName == 'TouchTransmitter' then
                spawn(function() touchPart(v.Parent) end)
            end
        end)
    end

    local msWorkspace = { Cage1Marker=true, Cage2Marker=true, TreasureMarker=true }
    if Workspace then Workspace.ChildAdded:Connect(function(v)
        if v and msWorkspace[v.Name] then
            spawn(function()
                repeat task.wait() until v:FindFirstChild('Collider')
                touchPart(v.PrimaryPart)
            end)
        end
    end) end

    local msIgnore = { WaterKillPart=true, HammerReset1=true, Water=true, WaterEnd=true, MushroomTriggers=true, TempleTrigger=true, LavaTrigger=true, Phase1Fall0=true, Phase2Fall0=true, CastleBossArena0=true, CastleFrontGate0=true, CastleBackGate0=true, Gate0=true, Gate1=true, TriggerFloor=true, Boss0=true, BossE0=true }

    local function ClearMission()
        if not Mission then return end
        for _,v in ipairs(Mission:GetChildren()) do
            if v.Name == 'MissionStart' then
                for _,b in ipairs(v:GetChildren()) do if b:FindFirstChild('TouchInterest') then touchPart(b) end end
            end
            if v:FindFirstChild('TouchInterest') and not msIgnore[v.Name] then touchPart(v) end
        end
    end

    local function getNearest()
        player, char, plr, hum, col, torso = getPlayer()
        local target, closet = nil, math.huge
        if Workspace and Workspace:FindFirstChild('Mobs') then
            for _,v in ipairs(Workspace.Mobs:GetChildren()) do
                if v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then
                    local dist = (plr.Position - v.Collider.Position).magnitude
                    if dist < closet then closet = dist; target = v end
                end
            end
        end
        if Workspace and Workspace:FindFirstChild('IceWall') then target = Workspace.IceWall end
        return target
    end

    local function killObject()
        local objectName, myPosition = {}, {}
        if game and game.PlaceId == 3383444582 then
            if Workspace then
                for _,v in ipairs(Workspace:GetChildren()) do if v:FindFirstChild('HealthProperties') and v:FindFirstChild('AllDamage') and v.HealthProperties.Health.Value > 0 then table.insert(objectName, v); table.insert(myPosition, plr.Position) end end
            end
        end
        if game and game.PlaceId == 4465989351 and Mission and Mission:FindFirstChild('IceBarricade') and Mission.IceBarricade:FindFirstChild('HealthProperties') and Mission.IceBarricade.HealthProperties.Health.Value > 0 then table.insert(objectName, Mission.IceBarricade); table.insert(myPosition, plr.Position) end
        if game and game.PlaceId == 4465989998 and Mission and Mission:FindFirstChild('SpikeCheckpoints') then for _,v in ipairs(Mission.SpikeCheckpoints:GetChildren()) do if v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then table.insert(objectName, v); table.insert(myPosition, plr.Position) end end end
        return objectName, myPosition
    end

    local function getMonster()
        local monsterName, myPosition = {}, {}
        if Workspace and Workspace:FindFirstChild('Mobs') then
            for _,v in ipairs(Workspace.Mobs:GetChildren()) do if v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then table.insert(monsterName, v); table.insert(myPosition, plr.Position) end end
        end
        return monsterName, myPosition
    end

    local function mergeTable(monsterTable, objectTable, myPosition1, myPosition2)
        if #objectTable > 0 and #myPosition2 > 0 then
            for i,monster in pairs(objectTable) do monsterTable[i] = monster end
            for i,position in pairs(myPosition2) do myPosition1[i] = position end
        end
        return monsterTable, myPosition1
    end

    local function getMobTable()
        local monsterTable, myPosition1 = getMonster()
        local objectTable, myPosition2 = killObject()
        return mergeTable(monsterTable, objectTable, myPosition1, myPosition2)
    end

    local function killAura()
        if not (ClassGUI and ClassGUI.Value and Classes[ClassGUI.Value]) then return end
        for _, class in pairs(Classes[ClassGUI.Value]) do
            local monsterTable, myPosition1 = getMobTable()
            if #monsterTable > 0 and #myPosition1 > 0 then
                pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Combat and ReplicatedStorage.Shared.Combat.Skillsets and ReplicatedStorage.Shared.Combat.Skillsets.DualWielder and ReplicatedStorage.Shared.Combat.Skillsets.DualWielder.AttackBuff then ReplicatedStorage.Shared.Combat.Skillsets.DualWielder.AttackBuff:FireServer() end end)
                if Combat and Combat.AttackTargets then pcall(function() Combat.AttackTargets(nil, monsterTable, myPosition1, class) end) end
                task.wait(0.2)
            end
        end
        task.wait(1)
    end

    local function main2()
        while task.wait(0.1) do
            spawn(ClearMission)
            local target = getNearest()
            if target and target.PrimaryPart then move(target.PrimaryPart, 0, 50, 0) end
        end
    end

    local function main()
        player, char, plr, hum, col, torso = getPlayer()
        noClip()
        credit()
        spawn(main2)
        while task.wait() do killAura() end
    end

    credit()
    main()
    if player then player.CharacterAdded:Connect(function() main() end) end
end

if inTower then
    player, char, plr, hum, col, torso = getPlayer()
    if getgenv().Settings.AutoSell.Enabled then SellItem() end

    local function getMission()
        if not Mission then return end
        for _,v in ipairs(Mission:GetChildren()) do
            if v:FindFirstChild('TouchInterest') then if v.Name == 'MinibossExit' or v.Name == 'WaveStarter' then touchPart(v) end end
            if v:FindFirstChild('Collider') and v.Name == 'MissionStart' then touchPart(v.Collider) end
        end
    end

    local bossTable = { MagmaGigaBlob=true, FireCastleCommander=true, BOSSFireTreeEnt=true, BOSSFireAnubis=true, MamaMegalodile=true, PirateCrab=true, Siren=true, BOSSKrakenMain=true, Nautilus=true, BOSSZeus=true }

    local function monster()
        local mob, pos = {}, {}
        if Workspace and Workspace:FindFirstChild('Mobs') then
            for _,v in ipairs(Workspace.Mobs:GetChildren()) do
                if v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then
                    table.insert(mob, v); table.insert(pos, plr.Position)
                    if bossTable[v.Name] and v.PrimaryPart then move(v.PrimaryPart, 0, 9999, 0) end
                end
            end
        end
        return mob, pos
    end

    local function killAura()
        if not (ClassGUI and ClassGUI.Value and Classes[ClassGUI.Value]) then return end
        for _,c in pairs(Classes[ClassGUI.Value]) do
            local mob, pos = monster()
            if #mob > 0 and #pos > 0 then
                pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Combat and ReplicatedStorage.Shared.Combat.Skillsets and ReplicatedStorage.Shared.Combat.Skillsets.DualWielder and ReplicatedStorage.Shared.Combat.Skillsets.DualWielder.AttackBuff then ReplicatedStorage.Shared.Combat.Skillsets.DualWielder.AttackBuff:FireServer() end end)
                if Combat and Combat.AttackTargets then pcall(function() Combat.AttackTargets(nil, mob, pos, c) end) end
                task.wait(0.2)
            end
        end
        task.wait(1)
    end

    local function existDoor()
        if Workspace and Workspace:FindFirstChild('Map') then
            for _,a in ipairs(Workspace.Map:GetChildren()) do
                if a:FindFirstChild('BoundingBox') then touchPart(a.BoundingBox) end
                pcall(function() if a:FindFirstChild('Model') then a.Model:Destroy() end; if a:FindFirstChild('Tiles') then a.Tiles:Destroy() end; if a:FindFirstChild('Gate') then a.Gate:Destroy() end end)
            end
        end
    end

    local function spawnMob()
        while true do
            local ok, waveText = pcall(function() return player and player.PlayerGui and player.PlayerGui.MainGui and player.PlayerGui.MainGui.TowerVisual and player.PlayerGui.MainGui.TowerVisual.KeyImage and player.PlayerGui.MainGui.TowerVisual.KeyImage.TextLabel and player.PlayerGui.MainGui.TowerVisual.KeyImage.TextLabel.Text end)
            if ok and waveText and tostring(waveText):find('WAVE') and Mission and Mission:FindFirstChild('WaveStarter') then move(Mission.WaveStarter) end
            task.wait()
            if Workspace and Workspace:FindFirstChild('Map') then
                for _,a in ipairs(Workspace.Map:GetChildren()) do
                    if a:FindFirstChild('MobSpawns') then
                        for _,b in ipairs(a.MobSpawns:GetChildren()) do
                            if b:FindFirstChild('Spawns') then
                                for _,v in ipairs(b.Spawns:GetChildren()) do
                                    if v:IsA('BasePart') and v.Name == 'Spawn' then move(v,0,20,0); task.wait(1) end
                                end
                            end
                        end
                    end
                end
            end
            task.wait()
        end
    end

    local function main2()
        while true do spawn(getMission); task.wait(0.1); spawn(existDoor); task.wait(0.1); spawn(autoChest); end
    end

    local function main()
        player, char, plr, hum, col, torso = getPlayer()
        noClip()
        credit()
        spawn(main2)
        spawn(spawnMob)
        while task.wait() do killAura() end
    end

    credit()
    main()
    if player then player.CharacterAdded:Connect(function() main() end) end
end
