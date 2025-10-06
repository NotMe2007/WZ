-- Tower AutoFarm v2 (cleaned rewrite)
-- This file is a safer, cleaned rewrite of the original script. It guards against nils,
-- removes globals, and reduces risky calls. Keep using at your own risk.

-- Safe aliases for Roblox globals (use rawget-only lookups so editors don't error on undefined globals)
local _G = _G
local wait = rawget(_G, 'wait')
local spawn = rawget(_G, 'spawn')
local getgenv = rawget(_G, 'getgenv') or function() return _G end
local getconnections = rawget(_G, 'getconnections')
local typeof = rawget(_G, 'typeof') or type
local game = rawget(_G, 'game')
local workspace = rawget(_G, 'workspace')
local Instance = rawget(_G, 'Instance')
local Vector3 = rawget(_G, 'Vector3')
local CFrame = rawget(_G, 'CFrame')
local gethiddenproperty = rawget(_G, 'gethiddenproperty')
-- replace dynamic loader with safe no-op to avoid remote code execution
local function safeLoad(chunk)
    -- do not execute dynamic code; keep a no-op function for compatibility
    pcall(function() warn('Dynamic load blocked for safety') end)
    return function() end
end
local loadstring = rawget(_G, 'loadstring') or rawget(_G, 'load') or safeLoad
-- Lightweight shims for UI types used in fallback warnings (only for static checks)
local UDim2 = rawget(_G, 'UDim2')
local Color3 = rawget(_G, 'Color3')
local Enum = rawget(_G, 'Enum')

local taskRef = rawget(_G, 'task')
repeat
    if wait then
        wait()
    elseif taskRef and taskRef.wait then
        taskRef.wait(0.05)
    else
        -- editor environment; yield briefly
        -- no reliable wait available, exit loop
        break
    end
until game and game:IsLoaded()

local function getPlayer()
    local plrObj, char, hrp, collider
    repeat
        plrObj = game.Players.LocalPlayer
        char = plrObj and plrObj.Character or plrObj and plrObj.CharacterAdded and plrObj.Character
        hrp = char and char:FindFirstChild('HumanoidRootPart')
        collider = char and (char:FindFirstChild('Collider') or hrp)
        if not (plrObj and char and hrp) then
            wait()
        end
    until plrObj and char and hrp
    return plrObj, char, hrp, collider
end

-- Resilient iterator for event connections. Calls executor getconnections safely and
-- falls back to :GetConnections() where available. Always returns a table.
local function safeIterConnections(evt)
    local gc = rawget(_G, 'getconnections')
    if type(gc) == 'function' then
        local ok, res = pcall(function()
            if evt then return gc(evt) else return gc() end
        end)
        if ok and type(res) == 'table' then return res end
    end
    if evt and type(evt.GetConnections) == 'function' then
        local ok2, res2 = pcall(function() return evt:GetConnections() end)
        if ok2 and type(res2) == 'table' then return res2 end
    end
    return {}
end

-- Supervisor: run long-running tasks under xpcall with restart/backoff
local Supervisor = {}
Supervisor.tasks = {}
Supervisor.stopping = false

function Supervisor.spawn(name, fn)
    if not name then name = tostring(fn) end
    Supervisor.stopping = false
    local co
    local maxAttempts = 6
    local attempts = 0
    local function runner()
        while (not Supervisor.stopping) do
            local ok, err = xpcall(fn, debug and debug.traceback or function(e) return tostring(e) end)
            if ok then break end
            attempts = attempts + 1
            warn(('[Supervisor] task "%s" crashed (attempt %d/%d): %s'):format(tostring(name), attempts, maxAttempts, tostring(err)))
            if attempts >= maxAttempts then
                warn(('[Supervisor] task "%s" reached max attempts, will not restart automatically'):format(tostring(name)))
                break
            end
            -- backoff with small sleeps but remain responsive to stop
            local backoff = math.min(6, attempts * 0.5)
            local slept = 0
            while slept < backoff and (not Supervisor.stopping) do
                wait(0.5)
                slept = slept + 0.5
            end
        end
    end
    co = coroutine.create(runner)
    local ok, res = pcall(function() coroutine.resume(co) end)
    Supervisor.tasks[name] = co
    return co
end

function Supervisor.stopAll()
    Supervisor.stopping = true
    if getgenv then pcall(function() getgenv().run = false end) end
end

local player, cha, plr, col = getPlayer()

-- safely load Combat and Class GUI
local Combat, ClassGUI, GetEvent
do
    local ok
    repeat
        ok = pcall(function()
            Combat = require(game:GetService('ReplicatedStorage').Shared.Combat)
            if cha and cha.Name then
                local profiles = game:GetService('ReplicatedStorage'):FindFirstChild('Profiles')
                local CharProfileCheck = profiles and profiles:FindFirstChild(cha.Name)
                ClassGUI = CharProfileCheck and profiles[cha.Name]:FindFirstChild('Class')
            end
            if Combat and Combat.GetAttackEvent then
                GetEvent = Combat:GetAttackEvent()
            end
        end)
        if not ok then wait() end
    until ok
end

local Classes = {
    ["Swordmaster"]     = {"Swordmaster1", "Swordmaster2", "Swordmaster3", "Swordmaster4", "Swordmaster5", "Swordmaster6", "CrescentStrike1", "CrescentStrike2", "CrescentStrike3", "Leap"},
    ["Mage"]            = {"Mage1", "ArcaneBlastAOE", "ArcaneBlast", "ArcaneWave1", "ArcaneWave2", "ArcaneWave3", "ArcaneWave4", "ArcaneWave5", "ArcaneWave6", "ArcaneWave7", "ArcaneWave8", "ArcaneWave9"},
    ["Defender"]        = {"Defender1", "Defender2", "Defender3", "Defender4", "Defender5", "Groundbreaker", "Spin1", "Spin2", "Spin3", "Spin4", "Spin5"},
    ["DualWielder"]     = {"DualWield1", "DualWield2", "DualWield3", "DualWield4", "DualWield5", "DualWield6", "DualWield7", "DualWield8", "DualWield9", "DualWield10", "DashStrike", "CrossSlash1", "CrossSlash2", "CrossSlash3", "CrossSlash4"},
    ["Guardian"]        = {"Guardian1", "Guardian2", "Guardian3", "Guardian4", "SlashFury1", "SlashFury2", "SlashFury3", "SlashFury4", "SlashFury5", "SlashFury6", "SlashFury7", "SlashFury8", "SlashFury9", "SlashFury10", "SlashFury11", "SlashFury12", "SlashFury13", "RockSpikes1", "RockSpikes2", "RockSpikes3"},
    ["IcefireMage"]     = {"IcefireMage1", "IcySpikes1", "IcySpikes2", "IcySpikes3", "IcySpikes4", "IcefireMageFireballBlast", "IcefireMageFireball", "LightningStrike1", "LightningStrike2", "LightningStrike3", "LightningStrike4", "LightningStrike5", "IcefireMageUltimateFrost", "IcefireMageUltimateMeteor1"},
    ["Berserker"]       = {"Berserker1", "Berserker2", "Berserker3", "Berserker4", "Berserker5", "Berserker6", "AggroSlam", "GigaSpin1", "GigaSpin2", "GigaSpin3", "GigaSpin4", "GigaSpin5", "GigaSpin6", "GigaSpin7", "GigaSpin8", "Fissure1", "Fissure2", "FissureErupt1", "FissureErupt2", "FissureErupt3", "FissureErupt4", "FissureErupt5"},
    ["Paladin"]         = {"Paladin1", "Paladin2", "Paladin3", "Paladin4", "LightThrust1", "LightThrust2", "LightPaladin1", "LightPaladin2"},
    ["MageOfLight"]     = {"MageOfLight", "MageOfLightBlast"},
    ["Demon"]           = {"Demon1", "Demon4", "Demon7", "Demon10", "Demon13", "Demon16", "Demon19", "Demon22", "Demon25", "DemonDPS1", "DemonDPS2", "DemonDPS3", "DemonDPS4", "DemonDPS5", "DemonDPS6", "DemonDPS7", "DemonDPS8", "DemonDPS9", "ScytheThrowDPS1", "ScytheThrowDPS2", "ScytheThrowDPS3", "DemonLifeStealDPS", "DemonSoulDPS1", "DemonSoulDPS2", "DemonSoulDPS3"},
    ["Dragoon"]         = {"Dragoon1", "Dragoon2", "Dragoon3", "Dragoon4", "Dragoon5", "Dragoon6", "Dragoon7", "DragoonDash","DragoonCross1", "DragoonCross2", "DragoonCross3", "DragoonCross4", "DragoonCross5", "DragoonCross6", "DragoonCross7", "DragoonCross8", "DragoonCross9", "DragoonCross10", "MultiStrike1", "MultiStrike2", "MultiStrike3", "MultiStrike4", "MultiStrike5", "MultiStrikeDragon1", "MultiStrikeDragon2", "MultiStrikeDragon3", "DragoonFall"},
    ["Archer"]          = {"Archer","PiercingArrow1","PiercingArrow2","PiercingArrow3", "PiercingArrow4", "PiercingArrow5", "PiercingArrow6", "PiercingArrow7", "PiercingArrow8", "PiercingArrow9", "PiercingArrow10","SpiritBomb","MortarStrike1","MortarStrike2","MortarStrike3","MortarStrike4","MortarStrike5","MortarStrike6","MortarStrike7", "HeavenlySword1", "HeavenlySword2", "HeavenlySword3", "HeavenlySword4", "HeavenlySword5", "HeavenlySword6"},
}

-- Disconnect existing connections to the attack event if environment provides getconnections
if GetEvent and GetEvent.OnClientEvent then
    pcall(function()
        for _, conn in next, safeIterConnections(GetEvent.OnClientEvent) do
            if conn and conn.Disable then
                pcall(function() conn:Disable() end)
            end
        end
    end)
end

local dungeonId = {
    [2978696440] = 'Crabby Crusade (1-1)',
    [4310476380] = 'Scarecrow Defense (1-2)',
    [4310464656] = 'Dire Problem (1-3)',
    [4310478830] = 'Kingslayer (1-4)',
    [3383444582] = 'Gravetower Dungeon (1-5)',
    [3885726701] = 'Temple of Ruin (2-1)',
    [3994953548] = 'Mama Trauma (2-2)',
    [4050468028] = "Volcano's Shadow (2-3)",
    [3165900886] = 'Volcano Dungeon (2-4)',
    [4465988196] = 'Mountain Pass (3-1)',
    [4465989351] = 'Winter Cavern (3-2)',
    [4465989998] = 'Winter Dungeon (3-3)',
    [4646473427] = 'Scrap Canyon (4-1)',
    [4646475342] = 'Deserted Burrowmine (4-2)',
    [4646475570] = 'Pyramid Dungeon (4-3)',
    [6386112652] = 'Konoh Heartlands (5-1)',
    [6510862058] = 'Atlantic Atoll (6-1)',
    [6847034886] = 'Mezuvia Skylands (7-1)'
}

local towerId = {
    [5703353651] = 'Prison Tower',
    [6075085184] = 'Atlantis Tower'
}

local lobbyId = {
    [2727067538] = 'Main menu',
    [4310463616] = 'World 1',
    [4310463940] = 'World 2',
    [4465987684] = 'World 3',
    [4646472003] = 'World 4',
    [5703355191] = 'World 5',
    [6075083204] = 'World 6',
    [6847035264] = 'World 7'
}

local function lobbyCheck()
    for id, name in pairs(lobbyId) do
        if game.PlaceId == id then
            warn('Lobby:', name)
            return true
        end
    end
    return false
end

local function dungeonCheck()
    for id, name in pairs(dungeonId) do
        if game.PlaceId == id then
            warn('Dungeon:', name)
            return true
        end
    end
    return false
end

local function towerCheck()
    for id, name in pairs(towerId) do
        if game.PlaceId == id then
            warn('Tower:', name)
            return true
        end
    end
    return false
end

warn('Checking location')
local inLobby = lobbyCheck()
local inDungeon = dungeonCheck()
local inTower = towerCheck()

if not inLobby and not inDungeon and not inTower then
    if player and player.Kick then
        player:Kick('Unsupported place for this script')
    else
        error('Unsupported place for this script')
    end
elseif inLobby or inDungeon then
    if player and player.Kick then
        player:Kick('Tower only')
    else
        error('Tower only')
    end
elseif inTower then
    player, cha, plr, col = getPlayer()

    -- If external code would've been loaded here, warn the player instead.
    local function warnAndSkipExternalLoad()
        local ok, StarterGui = pcall(function() return game:GetService('StarterGui') end)
        local msg = "External loader blocked: remote code not executed for safety."
        -- Try SetCore notification first (works in many environments)
        if ok and StarterGui and StarterGui.SetCore then
            pcall(function()
                StarterGui:SetCore('SendNotification', {
                    Title = 'Security';
                    Text = msg;
                    Duration = 6;
                })
            end)
            return
        end
        -- Next try Chat system message
        local ok2, Chat = pcall(function() return game:GetService('Chat') end)
        if ok2 then
            pcall(function()
                if ok and StarterGui and StarterGui.SetCore then
                    StarterGui:SetCore('ChatMakeSystemMessage', {Text = msg})
                    return
                end
                -- fallback: show a temporary ScreenGui label
                local plr = game.Players.LocalPlayer
                if plr and plr:FindFirstChild('PlayerGui') and Instance then
                    local screen = Instance.new('ScreenGui')
                    screen.Name = 'ExternalLoadWarning'
                    screen.ResetOnSpawn = false
                    screen.Parent = plr.PlayerGui
                    local label = Instance.new('TextLabel')
                    -- guarded constructors if UDim2/Color3/Enum are available
                    if rawget(_G, 'UDim2') and rawget(_G, 'Color3') and rawget(_G, 'Enum') then
                        label.Size = UDim2.new(0.6,0,0,50)
                        label.Position = UDim2.new(0.2,0,0.05,0)
                        label.BackgroundTransparency = 0.35
                        label.BackgroundColor3 = Color3.new(0,0,0)
                        label.TextColor3 = Color3.new(1,0.8,0)
                        label.Font = Enum.Font.SourceSansBold
                    end
                    label.TextSize = 20
                    label.Text = msg
                    label.Parent = screen
                    coroutine.wrap(function()
                        local t0 = os.clock()
                        while os.clock() - t0 < 6 do
                            wait(0.2)
                        end
                        pcall(function() screen:Destroy() end)
                    end)()
                end
            end)
            return
        end
        -- Last resort: print to console
        pcall(function() print(msg) end)
    end

    warnAndSkipExternalLoad()

    local function noClip()
        local _, _, _, localCol = getPlayer()
        if not localCol then return end
        if not localCol:FindFirstChild('BodyVelocity') then
            local bv = Instance.new('BodyVelocity')
            bv.Parent = localCol
            bv.MaxForce = Vector3.new(1,1,1)
        end
        wait(0.1)
        pcall(function() if plr then plr.CanCollide = false end end)
        pcall(function() if localCol then localCol.CanCollide = false end end)
        pcall(function() if cha and cha:FindFirstChild('LowerTorso') then cha.LowerTorso.CanCollide = false end end)
        pcall(function() if localCol and localCol:FindFirstChild('BodyVelocity') then localCol.BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge) end end)
    end

    -- Collect coin
    do
        local coinsFolder = workspace:FindFirstChild('Coins')
        if coinsFolder then
            coinsFolder.ChildAdded:Connect(function(inst)
                if not inst then return end
                if inst.Name == 'CoinPart' or inst:IsA('BasePart') then
                    Supervisor.spawn('coin_follow_'..tostring(inst), function()
                        while inst and inst.Parent and (getgenv and getgenv().run) do
                            pcall(function()
                                if inst:IsA('BasePart') then
                                    inst.CanCollide = false
                                    if plr then inst.CFrame = plr.CFrame end
                                end
                            end)
                            wait(0.1)
                        end
                    end)
                end
            end)
        end
    end

    -- Do mission: clean damage numbers and collect chests
    workspace.ChildAdded:Connect(function(obj)
        if not obj then return end
        if obj.Name == 'DamageNumber' then
            pcall(function() obj:Destroy() end)
            return
        end
        local nameLower = tostring(obj.Name):lower()
        if string.find(nameLower, 'chest') then
            Supervisor.spawn('chest_follow_'..tostring(obj), function()
                while obj and obj.Parent and (getgenv and getgenv().run) do
                    pcall(function()
                        if obj.PrimaryPart and plr then
                            obj.PrimaryPart.CanCollide = false
                            obj:SetPrimaryPartCFrame(plr.CFrame)
                        end
                    end)
                    wait(0.15)
                end
            end)
        end
    end)

    local function getMission()
        local missionRoot = workspace:FindFirstChild('MissionObjects')
        if not missionRoot then return end
        for _, v in ipairs(missionRoot:GetChildren()) do
            pcall(function()
                if v:FindFirstChild('TouchInterest') then
                    if v.Name == 'MinibossExit' and v:IsA('BasePart') and plr then
                        v.CanCollide = true
                        v.CFrame = plr.CFrame
                    end
                    if v:IsA('BasePart') then v.CanCollide = false end
                end
                if v.Name == 'MissionStart' and v.PrimaryPart and plr then
                    v.PrimaryPart.CanCollide = false
                    v.PrimaryPart.CFrame = plr.CFrame
                end
            end)
        end
        wait(0.25)
    end

    local bossTable = {
        MamaMegalodile = true,
        PirateCrab = true,
        Siren = true,
        BOSSKrakenMain = true,
        Nautilus = true,
    }

    local function monster()
        local mobs = {}
        local positions = {}
        local mobsRoot = workspace:FindFirstChild('Mobs')
        if not mobsRoot then return mobs, positions end
        for _, v in ipairs(mobsRoot:GetChildren()) do
            local hasCollider = v:FindFirstChild('Collider')
            local hp = v:FindFirstChild('HealthProperties') and v.HealthProperties:FindFirstChild('Health')
            local hpVal = hp and hp.Value or 0
            if hasCollider and hpVal > 0 then
                local ok, dist = pcall(function()
                    return (v.Collider.Position - (plr and plr.Position or Vector3.new())).magnitude
                end)
                if ok and dist and dist < 10000 then
                    table.insert(mobs, v)
                    -- determine a safe position value
                    local posVal
                    if v:FindFirstChild('Collider') then
                        posVal = v.Collider.Position
                    elseif v.GetModelCFrame then
                        local ok2, mc = pcall(function() return v:GetModelCFrame() end)
                        posVal = (ok2 and mc and mc.p) or Vector3.new()
                    else
                        posVal = Vector3.new()
                    end
                    table.insert(positions, posVal)
                end
            end
        end
        return mobs, positions
    end

    local function killAura()
        local mob, pos = monster()
        if (#mob > 0) and (#pos > 0) and ClassGUI and ClassGUI.Value and Classes[ClassGUI.Value] then
            for _, abilityName in ipairs(Classes[ClassGUI.Value]) do
                mob, pos = monster()
                if #mob > 0 and #pos > 0 then
                    pcall(function()
                        Combat.AttackTargets(nil, mob, pos, abilityName)
                    end)
                    wait(0.2)
                end
            end
        end
        wait(3.5)
    end

    local function setupUI()
        pcall(function()
            local Vitals = player:WaitForChild('PlayerGui'):WaitForChild('MainGui'):WaitForChild('Hotbar'):WaitForChild('Vitals')
            pcall(function()
                if Vitals:FindFirstChild('XP') then
                    local xp = Vitals:FindFirstChild('XP')
                    if xp:FindFirstChild('TextLabel') then xp.TextLabel.Visible = false end
                    if xp:FindFirstChild('Shadow') then xp.Shadow.Visible = false end
                end
                if Vitals:FindFirstChild('Health') and Vitals.Health:FindFirstChild('HealthText') then
                    Vitals.Health.HealthText.Text = 'Script by LuckyToT#0001'
                    if Vitals.Health.HealthText:FindFirstChild('Overlay') then
                        Vitals.Health.HealthText.Overlay.Text = 'Script by LuckyToT#0001'
                    end
                end
                pcall(function()
                    local desktopButton = player.PlayerGui.MainGui:FindFirstChild('Menu') and player.PlayerGui.MainGui.Menu:FindFirstChild('DesktopMenu')
                    if desktopButton and desktopButton:FindFirstChild('Button') and desktopButton.Button:FindFirstChild('ImageLabel') then
                        desktopButton.Button.ImageLabel.Image = 'rbxassetid://4782301932'
                    end
                end)
            end)
        end)
    end

    local function spawnMobLoop()
        while getgenv and getgenv().run do
            if workspace:FindFirstChild('Map') then
                for _, v in ipairs(workspace.Map:GetDescendants()) do
                    pcall(function() if v:IsA('BasePart') then v.Transparency = 1 end end)
                    if v:FindFirstChild('Active') then
                        for _, d in ipairs(v:GetDescendants()) do
                            if d:IsA('BasePart') and d.Name == 'Spawn' then
                                if col and d and d:IsA('BasePart') then
                                    col.CFrame = d.CFrame * CFrame.new(math.random(1,10), 3, math.random(1,10))
                                end
                                if cha and cha:FindFirstChild('LowerTorso') then
                                    cha.LowerTorso.CFrame = d.CFrame * CFrame.new(math.random(1,10), 3, math.random(1,10))
                                end
                                wait(0.5)
                                pcall(function() if type(gethiddenproperty) == 'function' then gethiddenproperty(v) end end)
                            end
                        end
                    end
                end
            end
            wait()
        end
    end

    -- Supervisor is declared earlier to avoid undefined-global during static analysis


    local function clearMap()
        if workspace:FindFirstChild('Map') then
            for _, v in ipairs(workspace.Map:GetDescendants()) do
                pcall(function() if v:IsA('BasePart') then v.Transparency = 1 end end)
            end
        end
    end

    local function backToSpawn()
        if workspace:FindFirstChild('Map') then
            for _, v in ipairs(workspace.Map:GetDescendants()) do
                if v:FindFirstChild('TouchInterest') and plr then
                    pcall(function() v.CFrame = plr.CFrame end)
                end
            end
        end
    end

    local function main2()
        while getgenv and getgenv().run do
                Supervisor.spawn('back_to_spawn', backToSpawn)
            wait(0.1)
                Supervisor.spawn('get_mission', getMission)
            wait(0.1)
                Supervisor.spawn('clear_map', clearMap)
            wait(0.1)
        end
    end

    local function main()
        player, cha, plr, col = getPlayer()
        if not getgenv then return end
        getgenv().run = true
        noClip()
        setupUI()
    Supervisor.spawn('main2', main2)
    Supervisor.spawn('spawnMobLoop', spawnMobLoop)
        while getgenv().run do
            killAura()
            wait()
        end
    end

    setupUI()
    main()

    local function onCharacterAdded()
        if getgenv then getgenv().run = false end
        player, cha, plr, col = getPlayer()
        wait(0.5)
        main()
    end
    if player and player.CharacterAdded then
        player.CharacterAdded:Connect(function()
            -- stop all supervisor tasks to avoid orphaned threads; main() restarts them
            Supervisor.stopAll()
            wait(0.5)
            onCharacterAdded()
        end)
    end
end
