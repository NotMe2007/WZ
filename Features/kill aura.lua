-- Kill Aura (robust, linter-friendly rewrite)

local game = rawget(_G, 'game') or error('game missing')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local Vector3 = rawget(_G, 'Vector3') or { new = function(x,y,z) return {x=x,y=y,z=z} end }
local spawn = function(f) coroutine.wrap(f)() end

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

-- Configuration via getgenv
local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
if _genv.killAuraEnabled == nil then _genv.killAuraEnabled = true end

-- Helpers to get player and character safely
local function getLocalPlayer()
    local plr = Players.LocalPlayer
    while not plr do wait(0.1) plr = Players.LocalPlayer end
    return plr
end

local function getCharacterParts(plr)
    if not plr then return nil end
    local cha = plr.Character or plr.CharacterAdded and plr.CharacterAdded:Wait()
    if not cha then return nil end
    local hrp = cha:FindFirstChild('HumanoidRootPart') or cha:FindFirstChild('Torso')
    local head = cha:FindFirstChild('Head')
    return cha, hrp, head
end

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

-- Attempt to load Combat module and disable client-side handlers if possible
local Combat = safeRequire(ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Combat') or nil)
do
    local ok, getEvent = pcall(function()
        if Combat and type(Combat.GetAttackEvent) == 'function' then
            return Combat:GetAttackEvent()
        end
        return nil
    end)
    if ok and getEvent then
        local gc = rawget(_G, 'getconnections')
        if type(gc) == 'function' and getEvent.OnClientEvent then
            pcall(function()
                for _, conn in next, gc(getEvent.OnClientEvent) do
                    if conn and type(conn.Disable) == 'function' then
                        pcall(function() conn:Disable() end)
                    end
                end
            end)
        end
    end
end

-- Find class GUI value safely
local function findClassValue(plr)
    if not ReplicatedStorage:FindFirstChild('Profiles') then return nil end
    local profiles = ReplicatedStorage.Profiles
    local proto = profiles:FindFirstChild(plr.Name) or profiles:FindFirstChild('NT_Script')
    if not proto then return nil end
    return proto:FindFirstChild('Class')
end

-- Find nearby mobs and return list + positions expected by Combat.AttackTargets
local function findTargets(plr, range)
    local mobs = {}
    local poses = {}
    if not plr or not ReplicatedStorage then return mobs, poses end
    local workspace = game:GetService('Workspace')
    local mobFolder = workspace:FindFirstChild('Mobs')
    if not mobFolder then return mobs, poses end
    local _, _, head = getCharacterParts(plr)
    for _, v in ipairs(mobFolder:GetChildren()) do
        pcall(function()
            if v and v:FindFirstChild('Collider') and v:FindFirstChild('HealthProperties') and v.HealthProperties.Health and v.HealthProperties.Health.Value > 0 then
                local collider = v.Collider
                local pos = collider.Position
                local myPos = head and head.Position or (plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character.HumanoidRootPart.Position)
                if myPos then
                    local dist = (pos - myPos).magnitude
                    if dist < (range or 10000) then
                        table.insert(mobs, v)
                        table.insert(poses, (myPos + Vector3.new(0, 100, 0)))
                    end
                end
            end
        end)
    end
    return mobs, poses
end

-- Control API
local API = {}
API.running = false

function API.start()
    if API.running then return end
    API.running = true
    spawn(function()
        local plr = getLocalPlayer()
        local classVal = findClassValue(plr)
        while API.running and (_genv.killAuraEnabled == nil or _genv.killAuraEnabled) do
            local mobs, poses = findTargets(plr)
            if #mobs > 0 and (#poses > 0) then
                local className = classVal and classVal.Value or nil
                local classList = className and Classes[className]
                if classList and Combat and type(Combat.AttackTargets) == 'function' then
                    for _, attackName in ipairs(classList) do
                        pcall(function()
                            -- refresh targets before each attack to be resilient
                            mobs, poses = findTargets(plr)
                            if #mobs > 0 then
                                Combat:AttackTargets(nil, mobs, poses, attackName)
                            end
                        end)
                        wait(0.2)
                        if not API.running then break end
                    end
                end
            end
            wait(3.5)
        end
        API.running = false
    end)
end

function API.stop()
    API.running = false
    _genv.killAuraEnabled = false
end

function API.toggle()
    if API.running then API.stop() else API.start() end
end

-- Start automatically if configured
if _genv.killAuraEnabled then
    API.start()
end

return API


