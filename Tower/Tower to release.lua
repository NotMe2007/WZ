-- Tower to release (cleaned)
-- Preserves original logic but adds guards for editor/static checks and runtime nil-safes.

-- Safe environment aliases (work in Roblox, provide fallbacks for static checks)
local _G_env = _G
local game = rawget(_G_env, 'game') or nil
local workspace = rawget(_G_env, 'workspace') or (game and game:GetService('Workspace')) or nil
local task = rawget(_G_env, 'task') or { wait = function() end, spawn = function(fn) fn() end }
local spawn = rawget(_G_env, 'spawn') or (task and task.spawn) or function(fn) fn() end
local wait = task.wait
local Instance = rawget(_G_env, 'Instance') or { new = function() return nil end }
local Vector3 = rawget(_G_env, 'Vector3') or { new = function() return nil end }
local CFrame = rawget(_G_env, 'CFrame') or { new = function() return nil end }
local firetouchinterest = rawget(_G_env, 'firetouchinterest') or function() end
local getconnections = rawget(_G_env, 'getconnections') or function() return {} end
local loadstring = rawget(_G_env, 'loadstring') or rawget(_G_env, 'load') or function() return nil end
local setclipboard = rawget(_G_env, 'setclipboard') or function() end
local typeof = rawget(_G_env, 'typeof') or function(v) return type(v) end

-- safe getgenv alias for static checks
local _getgenv_raw = rawget(_G_env, 'getgenv')
local function getgenv()
    if type(_getgenv_raw) == 'function' then return _getgenv_raw() end
    return {}
end

local function safeGetService(name)
    if game and game.GetService then return game:GetService(name) end
    return setmetatable({}, { __index = function() return function() end end })
end

local Players = safeGetService('Players')
local ReplicatedStorage = safeGetService('ReplicatedStorage')
local Lighting = safeGetService('Lighting')

-- Ensure runtime ready
if game and game.IsLoaded then repeat wait() until game:IsLoaded() end

-- Safe player getter
local function getPlayer()
    local plr = Players.LocalPlayer
    while not plr do wait(); plr = Players.LocalPlayer end
    local ch = plr.Character or plr.CharacterAdded:Wait()
    local hrp = ch:WaitForChild('HumanoidRootPart')
    local col = ch:FindFirstChild('Collider') or hrp
    local torso = ch:FindFirstChild('LowerTorso') or ch:FindFirstChild('Torso') or hrp
    local hum = ch:FindFirstChild('Humanoid')
    return plr, ch, hrp, hum, col, torso
end

local player, cha, plr, hum, col, torso = getPlayer()

-- Load shared modules guarded
local Combat
local ClassGUI
local GetEvent
local Mission
pcall(function()
    Combat = (ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Combat) and require(ReplicatedStorage.Shared.Combat) or nil
    if ReplicatedStorage and ReplicatedStorage:FindFirstChild('Profiles') and cha and ReplicatedStorage.Profiles:FindFirstChild(cha.Name) then
        ClassGUI = ReplicatedStorage.Profiles[cha.Name].Class
    end
    GetEvent = Combat and Combat.GetAttackEvent and Combat:GetAttackEvent() or nil
    Mission = workspace and workspace:FindFirstChild('MissionObjects') or nil
end)

-- Small helper: safe call
local function safeCall(fn, ...)
    if not fn then return false end
    return pcall(fn, ...)
end

-- Clear/cleanup map visuals
local function ClearMap()
    pcall(function()
        for _,v in ipairs(Lighting:GetChildren()) do
            if v:IsA('Sky') then
                v.MoonTextureId = 'rbxassetid://3176877317'
                v.SkyboxBk = 'rbxassetid://3176877317'
                v.SkyboxDn = 'rbxassetid://3176877696'
                v.SkyboxFt = 'rbxassetid://3176878020'
                v.SkyboxLf = 'rbxassetid://3176878336'
                v.SkyboxRt = 'rbxassetid://3176878576'
                v.SkyboxUp = 'rbxassetid://3176878816'
                v.SunTextureId = 'rbxassetid://1084351190'
            end
        end

        if workspace then
            for _,name in ipairs({'WaveDefenseRoom','BossBuilding','SpawnRoom'}) do
                local obj = workspace:FindFirstChild(name)
                if obj then pcall(function() obj:Destroy() end) end
            end
        end

        if Mission then
            pcall(function()
                if Mission:FindFirstChild('GatesAAA') then Mission.GatesAAA:Destroy() end
                if Mission:FindFirstChild('CeilingGood') then Mission.CeilingGood:Destroy() end
            end)
        end

        if workspace and workspace.Terrain then pcall(function() workspace.Terrain:Clear() end) end
    end)
end

-- Build Classes table
local Classes = { -- kept minimal formatting
    Swordmaster = {'Swordmaster1','Swordmaster2','Swordmaster3','Swordmaster4','Swordmaster5','Swordmaster6','CrescentStrike1','CrescentStrike2','CrescentStrike3','Leap'},
    Mage = {'Mage1','ArcaneBlastAOE','ArcaneBlast','ArcaneWave1','ArcaneWave2','ArcaneWave3','ArcaneWave4','ArcaneWave5','ArcaneWave6','ArcaneWave7','ArcaneWave8','ArcaneWave9'},
    Defender = {'Defender1','Defender2','Defender3','Defender4','Defender5','Groundbreaker','Spin1','Spin2','Spin3','Spin4','Spin5'},
    DualWielder = {'DualWield1','DualWield2','DualWield3','DualWield4','DualWield5','DualWield6','DualWield7','DualWield8','DualWield9','DualWield10','DashStrike','CrossSlash1','CrossSlash2','CrossSlash3','CrossSlash4'},
    Guardian = {'Guardian1','Guardian2','Guardian3','Guardian4','SlashFury1','SlashFury2','SlashFury3','SlashFury4','SlashFury5','SlashFury6','SlashFury7','SlashFury8','SlashFury9','SlashFury10','SlashFury11','SlashFury12','SlashFury13','RockSpikes1','RockSpikes2','RockSpikes3'},
    IcefireMage = {'IcefireMage1','IcySpikes1','IcySpikes2','IcySpikes3','IcySpikes4','IcefireMageFireballBlast','IcefireMageFireball','LightningStrike1','LightningStrike2','LightningStrike3','LightningStrike4','LightningStrike5','IcefireMageUltimateFrost','IcefireMageUltimateMeteor1'},
    Berserker = {'Berserker1','Berserker2','Berserker3','Berserker4','Berserker5','Berserker6','AggroSlam','GigaSpin1','GigaSpin2','GigaSpin3','GigaSpin4','GigaSpin5','GigaSpin6','GigaSpin7','GigaSpin8','Fissure1','Fissure2','FissureErupt1','FissureErupt2','FissureErupt3','FissureErupt4','FissureErupt5'},
    Paladin = {'Paladin1','Paladin2','Paladin3','Paladin4','LightThrust1','LightThrust2','LightPaladin1','LightPaladin2'},
    MageOfLight = {'MageOfLight','MageOfLightBlast'},
    Demon = {'Demon1','Demon4','Demon7','Demon10','Demon13','Demon16','Demon19','Demon22','Demon25','DemonDPS1','DemonDPS2','DemonDPS3','DemonDPS4','DemonDPS5','DemonDPS6','DemonDPS7','DemonDPS8','DemonDPS9','ScytheThrowDPS1','ScytheThrowDPS2','ScytheThrowDPS3','DemonLifeStealDPS','DemonSoulDPS1','DemonSoulDPS2','DemonSoulDPS3'},
    Dragoon = {'Dragoon1','Dragoon2','Dragoon3','Dragoon4','Dragoon5','Dragoon6','Dragoon7','DragoonDash','DragoonCross1','DragoonCross2','DragoonCross3','DragoonCross4','DragoonCross5','DragoonCross6','DragoonCross7','DragoonCross8','DragoonCross9','DragoonCross10','MultiStrike1','MultiStrike2','MultiStrike3','MultiStrike4','MultiStrike5','MultiStrikeDragon1','MultiStrikeDragon2','MultiStrikeDragon3','DragoonFall'},
    Archer = {'Archer','PiercingArrow1','PiercingArrow2','PiercingArrow3','PiercingArrow4','PiercingArrow5','PiercingArrow6','PiercingArrow7','PiercingArrow8','PiercingArrow9','PiercingArrow10','SpiritBomb','MortarStrike1','MortarStrike2','MortarStrike3','MortarStrike4','MortarStrike5','MortarStrike6','MortarStrike7','HeavenlySword1','HeavenlySword2','HeavenlySword3','HeavenlySword4','HeavenlySword5','HeavenlySword6'},
}

-- Disable connections to attack event if present
if GetEvent and GetEvent.OnClientEvent and typeof(getconnections) == 'function' then
    pcall(function()
        for _,conn in ipairs(getconnections(GetEvent.OnClientEvent)) do
            pcall(function() if conn and conn.Disable then conn:Disable() end end)
        end
    end)
end

-- Item helpers
local function getItemList()
    local list = {}
    local ok, Items = pcall(function() return require(ReplicatedStorage.Shared.Items) end)
    if not ok or type(Items) ~= 'table' then return list end
    for _,info in pairs(Items) do
        if type(info) == 'table' and info.Type and (info.Type == 'Weapon' or info.Type == 'Armor') then
            table.insert(list, info)
        end
    end
    return list
end

local function getItemName()
    local names = {}
    pcall(function()
        if ReplicatedStorage and ReplicatedStorage.Profiles and cha and ReplicatedStorage.Profiles[cha.Name] and ReplicatedStorage.Profiles[cha.Name].Inventory and ReplicatedStorage.Profiles[cha.Name].Inventory.Items then
            for _,v in ipairs(ReplicatedStorage.Profiles[cha.Name].Inventory.Items:GetChildren()) do
                if v:FindFirstChild('Level') or v:FindFirstChild('Upgrade') or v:FindFirstChild('UpgradeLimit') then
                    if not tostring(v.Name):lower():find('pet') then table.insert(names, v) end
                end
            end
        end
    end)
    return names
end

local function ToSell()
    local toSell = {}
    local types = getItemList()
    local names = getItemName()
    for _,inv in ipairs(names) do
        for _,info in ipairs(types) do
            if tostring(info.Name) == tostring(inv) then
                local rarity = info.Rarity
                if getgenv().Common and rarity == 1 then table.insert(toSell, inv) end
                if getgenv().Uncommon and rarity == 2 then table.insert(toSell, inv) end
                if getgenv().Rare and rarity == 3 then table.insert(toSell, inv) end
                if getgenv().Epic and rarity == 4 then table.insert(toSell, inv) end
                if getgenv().Legendary and rarity == 5 then table.insert(toSell, inv) end
            end
        end
    end
    return toSell
end

local function SellItem()
    local items = ToSell()
    if #items > 0 and ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Drops and ReplicatedStorage.Shared.Drops.SellItems then
        pcall(function() ReplicatedStorage.Shared.Drops.SellItems:InvokeServer(items) end)
    end
end

-- Place ID maps
local dungeonId = { [2978696440]='Crabby Crusade (1-1)', [4310476380]='Scarecrow Defense (1-2)', [4310464656]='Dire Problem (1-3)', [4310478830]='Kingslayer (1-4)', [3383444582]='Gravetower Dungeon (1-5)', [3885726701]='Temple of Ruin (2-1)', [3994953548]='Mama Trauma (2-2)', [4050468028]="Volcano's Shadow (2-3)", [3165900886]='Volcano Dungeon (2-4)', [4465988196]='Mountain Pass (3-1)', [4465989351]='Winter Cavern (3-2)', [4465989998]='Winter Dungeon (3-3)', [4646473427]='Scrap Canyon (4-1)', [4646475342]='Deserted Burrowmine (4-2)', [4646475570]='Pyramid Dungeon (4-3)', [6386112652]='Konoh Heartlands (5-1)', [6510862058]='Atlantic Atoll (6-1)', [6847034886]='Mezuvia Skylands (7-1)' }
local towerId = { [5703353651]='Prison Tower', [6075085184]='Atlantis Tower', [7071564842]='Mezuvian Tower' }
local lobbyId = { [2727067538]='Main menu', [4310463616]='World 1', [4310463940]='World 2', [4465987684]='World 3', [4646472003]='World 4', [5703355191]='World 5', [6075083204]='World 6', [6847035264]='World 7' }

local function lobbyCheck()
    for id,name in pairs(lobbyId) do if game and game.PlaceId == id then warn('Lobby:', name); return true end end; return false
end
local function dungeonCheck()
    for id,name in pairs(dungeonId) do if game and game.PlaceId == id then warn('Dungeon:', name); return true end end; return false
end
local function towerCheck()
    for id,name in pairs(towerId) do if game and game.PlaceId == id then warn('Tower:', name); return true end end; return false
end

local inLobby, inDungeon, inTower = lobbyCheck(), dungeonCheck(), towerCheck()

-- UI load (safe)
local library
pcall(function()
    if game and game.HttpGet then
        local ok, s = pcall(function() return game:HttpGet('https://raw.githubusercontent.com/LuckyToT/Roblox/main/UI/Wally%20UI%20III.lua') end)
        if ok and type(s) == 'string' then
            local f = loadstring(s)
            if f then
                local ok2, res = pcall(f)
                if ok2 then library = res end
            end
        end
    end
end)
local Game = library and library.CreateWindow and library:CreateWindow('AutoFarm Tower') or nil
local Credit = Game and Game.CreateFolder and Game:CreateFolder('Credit') or nil
local Update = Game and Game.CreateFolder and Game:CreateFolder('Latest Updated') or nil

-- Credit UI (safe noop if missing)
if Credit and Credit.Label then
    pcall(function() Credit:Label('Script: LuckyToT#0001',{ TextSize=16 }) end)
    pcall(function() Credit:Button('Copy user', function() if rawget(_G,'setclipboard') then setclipboard('LuckyToT#0001') end end) end)
end

-- Early exit if not in supported place
if not inLobby and not inDungeon and not inTower then if player and player.Kick then player:Kick('S U S') end return end

if inLobby then
    SellItem()
    pcall(function() if ReplicatedStorage and ReplicatedStorage.Shared and ReplicatedStorage.Shared.Teleport and ReplicatedStorage.Shared.Teleport.StartRaid then ReplicatedStorage.Shared.Teleport.StartRaid:FireServer(getgenv().Tower) end end)
    return
end

if inDungeon then
    if player and player.Kick then player:Kick('Tower only') end
    return
end

-- inTower logic
if inTower then
    player, cha, plr, hum, col, torso = getPlayer()
    SellItem()

    repeat
        local ok
        ok = pcall(function()
            A = workspace and workspace:FindFirstChild('Coins')
            B = workspace and workspace:FindFirstChild('MissionObjects')
            C = workspace and workspace:FindFirstChild('Mobs')
        end)
        wait()
    until ok

    wait(3)

    local function noClip()
        player, cha, plr, hum, col, torso = getPlayer()
        pcall(function()
            if col and not col:FindFirstChild('BodyVelocity') then
                local bv = Instance.new('BodyVelocity')
                bv.Parent = col
            end
            wait(0.1)
            if plr then plr.CanCollide = false end
            if col then col.CanCollide = false end
            if torso then torso.CanCollide = false end
            if col and col:FindFirstChild('BodyVelocity') then
                pcall(function() col.BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge) end)
            end
        end)
        ClearMap()
    end

    -- coin magnet
    if workspace and workspace:FindFirstChild('Coins') then
        workspace.Coins.ChildAdded:Connect(function(v)
            if v and v.Name == 'CoinPart' and getgenv().CoinMagnet then
                spawn(function()
                    while v and v.Parent do
                        pcall(function() if plr and v:IsA('BasePart') then v.CanCollide = false; v.CFrame = plr.CFrame end end)
                        wait(0.2)
                    end
                end)
            end
        end)
    end

    local function autoChest()
        if workspace then
            for _,v in ipairs(workspace:GetChildren()) do
                if v:IsA('Model') and tostring(v.Name):lower():find('chest') and getgenv().AutoChest then
                    pcall(function() if v.PrimaryPart and plr then v.PrimaryPart.CFrame = plr.CFrame end end)
                end
            end
        end
    end

    workspace.ChildAdded:Connect(function(v) if v and v.Name == 'DamageNumber' and getgenv().RemoveDamage then pcall(function() v:Destroy() end) end end)

    local function getMission()
        if not workspace or not workspace:FindFirstChild('MissionObjects') then return end
        for _,v in ipairs(workspace.MissionObjects:GetChildren()) do
            if v:FindFirstChild('TouchInterest') then
                if v.Name == 'MinibossExit' or v.Name == 'WaveStarter' then
                    pcall(function() firetouchinterest(plr, v, 0); wait(.25); firetouchinterest(plr, v, 1) end)
                end
            end
            if v:FindFirstChild('Collider') and v.Name == 'MissionStart' then
                spawn(function()
                    repeat
                        pcall(function() firetouchinterest(plr, v.Collider, 0); wait(.25); firetouchinterest(plr, v.Collider, 1) end)
                        wait(.5)
                    until not v or not v.Parent or not v:FindFirstChild('Collider')
                end)
            end
        end
    end

    local bossTable = { MagmaGigaBlob=true, FireCastleCommander=true, BOSSFireTreeEnt=true, BOSSFireAnubis=true, MamaMegalodile=true, PirateCrab=true, Siren=true, BOSSKrakenMain=true, Nautilus=true, BOSSZeus=true }

    local function monster()
        local mob, pos = {}, {}
        if workspace and workspace:FindFirstChild('Mobs') then
            for _,v in ipairs(workspace.Mobs:GetChildren()) do
                if v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health.Value > 0 then
                    local ok, dist = pcall(function() return (v.Collider.Position - plr.Position).magnitude end)
                    if ok and dist and dist < 10000 then table.insert(mob, v); table.insert(pos, plr.Position) end
                    if bossTable[v.Name] and v.PrimaryPart then pcall(function() if col then col.CFrame = v.PrimaryPart.CFrame * CFrame.new(0,1000,0); if torso then torso.CFrame = v.PrimaryPart.CFrame * CFrame.new(0,1000,0) end end end) end
                end
            end
        end
        return mob, pos
    end

    local function killAura()
        if not (ClassGUI and ClassGUI.Value and Classes[ClassGUI.Value]) then return end
        for _,skill in ipairs(Classes[ClassGUI.Value]) do
            local mob, pos = monster()
            if #mob > 0 and #pos > 0 then
                pcall(function()
                    if Combat and Combat.AttackTargets then Combat.AttackTargets(nil, mob, pos, skill) end
                end)
                wait(0.2)
            end
        end
        wait(1)
    end

    -- UI tweaks and credit (guarded)
    pcall(function()
        local Vitals = player and player:FindFirstChild('PlayerGui') and player.PlayerGui:FindFirstChild('MainGui') and player.PlayerGui.MainGui:FindFirstChild('Hotbar') and player.PlayerGui.MainGui.Hotbar:FindFirstChild('Vitals')
        if Vitals then
            pcall(function()
                if Vitals:FindFirstChild('XP') then if Vitals.XP:FindFirstChild('TextLabel') then Vitals.XP.TextLabel.Visible = false end; if Vitals.XP:FindFirstChild('Shadow') then Vitals.XP.Shadow.Visible = false end end
                if Vitals:FindFirstChild('Health') and Vitals.Health:FindFirstChild('HealthText') then Vitals.Health.HealthText.Text = 'Script by LuckyToT#0001'; if Vitals.Health.HealthText:FindFirstChild('Overlay') then Vitals.Health.HealthText.Overlay.Text = 'Script by LuckyToT#0001' end end
            end)
        end
    end)

    local function existDoor()
        if workspace and workspace:FindFirstChild('Map') then
            for _,a in ipairs(workspace.Map:GetChildren()) do
                if a:FindFirstChild('BoundingBox') then pcall(function() firetouchinterest(plr, a.BoundingBox, 0); wait(.25); firetouchinterest(plr, a.BoundingBox, 1) end) end
                pcall(function() if a:FindFirstChild('Model') then a.Model:Destroy() end; if a:FindFirstChild('Tiles') then a.Tiles:Destroy() end; if a:FindFirstChild('Gate') then a.Gate:Destroy() end end)
            end
        end
    end

    local function spawnMob()
        while true do
            local waveText = nil
            pcall(function() waveText = player.PlayerGui.MainGui.TowerVisual.KeyImage.TextLabel.Text end)
            if workspace and workspace:FindFirstChild('Map') then
                for _,a in ipairs(workspace.Map:GetChildren()) do
                    if a:FindFirstChild('MobSpawns') then
                        for _,b in ipairs(a.MobSpawns:GetChildren()) do
                            if b:FindFirstChild('Spawns') then
                                for _,v in ipairs(b.Spawns:GetChildren()) do
                                    if v:IsA('BasePart') and v.Name == 'Spawn' then
                                        pcall(function()
                                            if col then
                                                col.CFrame = v.CFrame * CFrame.new(math.random(1,10),20,math.random(1,10))
                                            end
                                            if torso then
                                                torso.CFrame = v.CFrame * CFrame.new(math.random(1,10),20,math.random(1,10))
                                            end
                                        end)
                                        wait(0.7)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif waveText and tostring(waveText):find('WAVE') and workspace and workspace:FindFirstChild('MissionObjects') and workspace.MissionObjects:FindFirstChild('WaveStarter') then
                pcall(function() if plr then plr.CFrame = workspace.MissionObjects.WaveStarter.CFrame end end)
            end
            wait(0.2)
        end
    end

    local function main2()
        while true do
            spawn(getMission)
            wait(0.2)
            spawn(existDoor)
            wait(0.2)
            spawn(autoChest)
        end
    end

    local function main()
        player, cha, plr, hum, col, torso = getPlayer()
        noClip()
        spawn(main2)
        spawn(spawnMob)
        while true do
            killAura()
            wait()
        end
    end

    credit()
    ClearMap()
    main()
    if player then player.CharacterAdded:Connect(function() main() end) end
end
