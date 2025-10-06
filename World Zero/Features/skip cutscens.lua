-- Improved skip-cutscenes helper (defensive + linter-friendly)
local game = rawget(_G, 'game') or error('game global missing')
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
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

local function safeRequire(mod)
    if not mod then return nil end
    local ok, res = pcall(require, mod)
    if ok then return res end
    return nil
end

local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}
local function shouldSkip()
    return _genv.skip == true
end

local function getLocalPlayer()
    local plr = Players.LocalPlayer
    while not plr do wait(0.1) plr = Players.LocalPlayer end
    return plr
end

local player = getLocalPlayer()

-- Attempt to obtain the camera module once (best-effort)
local CameraModule = safeRequire(ReplicatedStorage.Client and ReplicatedStorage.Client.Camera or nil)

local function trySkip()
    if not shouldSkip() then return end
    if CameraModule and type(CameraModule.SkipCutscene) == 'function' then
        pcall(function() CameraModule:SkipCutscene() end)
        return
    end
    -- fallback: if CutsceneUI exposes a Changed event that indicates playback, try to call module again
    local pg = player and player:FindFirstChild('PlayerGui')
    if not pg then return end
    local cut = pg:FindFirstChild('CutsceneUI')
    if cut and cut.Changed then
        pcall(function()
            if CameraModule and type(CameraModule.SkipCutscene) == 'function' then
                CameraModule:SkipCutscene()
            end
        end)
    end
end

-- Watch for CutsceneUI appearing and react
local function watchPlayerGui(plr)
    if not plr then return end
    local pg = plr:WaitForChild('PlayerGui')
    -- immediate attempt if already present
    if pg:FindFirstChild('CutsceneUI') then trySkip() end

    pg.ChildAdded:Connect(function(child)
        if child and child.Name == 'CutsceneUI' then
            -- small debounce to allow initialization
            wait(0.05)
            trySkip()
            -- also connect Changed to re-try if needed
            if child.Changed then
                child.Changed:Connect(function()
                    trySkip()
                end)
            end
        end
    end)
end

watchPlayerGui(player)

-- Optional: if player respawns / changes, reattach watcher
Players.PlayerAdded:Connect(function(pl)
    if pl == Players.LocalPlayer then watchPlayerGui(pl) end
end)

-- Expose a simple API for runtime toggling via getgenv()
return {
    trySkip = trySkip,
    shouldSkip = shouldSkip,
}