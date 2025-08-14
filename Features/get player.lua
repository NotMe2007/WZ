-- Features/get player.lua
-- Small module that reliably returns LocalPlayer and key character parts.

local game = rawget(_G, 'game') or error('game global missing')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do RunService.Heartbeat:Wait() end
    else
        RunService.Heartbeat:Wait()
    end
end

local function getPlayer(opts)
    opts = opts or {}
    local timeout = tonumber(opts.timeout) -- seconds, nil = wait forever
    local started = os.clock()

    local function timedOut()
        return timeout and (os.clock() - started) >= timeout
    end

    local plr = Players.LocalPlayer
    while not plr do
        if timedOut() then return nil, 'timeout waiting for LocalPlayer' end
        wait(0.05)
        plr = Players.LocalPlayer
    end

    local cha = plr.Character or (plr.CharacterAdded and plr.CharacterAdded:Wait())
    if not cha then return nil, 'no character' end

    local function waitForChildSafe(instance, name)
        local obj = instance:FindFirstChild(name)
        local t0 = os.clock()
        while not obj do
            if timedOut() then return nil end
            wait(0.05)
            obj = instance:FindFirstChild(name)
        end
        return obj
    end

    local hrp = waitForChildSafe(cha, 'HumanoidRootPart')
    local humanoid = waitForChildSafe(cha, 'Humanoid')
    local collider = cha:FindFirstChild('Collider') or cha:FindFirstChild('Torso') or cha:FindFirstChild('UpperTorso') or cha:FindFirstChild('LowerTorso')
    local lowerTorso = cha:FindFirstChild('LowerTorso') or cha:FindFirstChild('UpperTorso')

    if not hrp or not humanoid then return nil, 'missing essential parts' end

    return plr, cha, hrp, humanoid, collider, lowerTorso
end

-- Return module API
return {
    get = getPlayer,
}