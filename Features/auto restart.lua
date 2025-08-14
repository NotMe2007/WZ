
local game = rawget(_G, 'game') or error('game missing')
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

local _genv = (type(rawget(_G, 'getgenv')) == 'function' and rawget(_G, 'getgenv')()) or {}

-- Attempt to load Menu module if available
local MenuModule = nil
local function tryLoadMenu()
    local ok, mod = pcall(function()
        local candidate = ReplicatedStorage:FindFirstChild('Features') and ReplicatedStorage.Features:FindFirstChild('Menu') or nil
        if candidate then return require(candidate) end
        return nil
    end)
    if ok and mod then MenuModule = mod else MenuModule = nil end
end
tryLoadMenu()

local function getAutoRestartConfig()
    -- returns enabled(bool), delay(number), towerId(number)
    -- prefer MenuModule, fall back to _genv.Settings.AutoRejoin
    if MenuModule and type(MenuModule.get) == 'function' then
        local enabled = MenuModule.get('Settings.AutoRejoin.Enabled')
        local delay = MenuModule.get('Settings.AutoRejoin.Delay')
        local tower = MenuModule.get('Settings.Tower.CustomTower.TowerId')
        return (enabled == true), tonumber(delay) or 5, tonumber(tower) or 27
    end
    -- fallback to _genv
    if _genv.Settings and _genv.Settings.AutoRejoin then
        return (_genv.Settings.AutoRejoin.Enabled == true), tonumber(_genv.Settings.AutoRejoin.Delay) or 5, tonumber(_genv.Tower) or 27
    end
    return false, 5, 27
end

-- Exposed settings API: isEnabled / setEnabled / toggle
local function isEnabled()
    local enabled = getAutoRestartConfig()
    return enabled
end

local function persistEnabled(val)
    if MenuModule and type(MenuModule.set) == 'function' then
        pcall(function() MenuModule.set('Settings.AutoRejoin.Enabled', val == true) end)
        return
    end
    -- fallback to _genv
    _genv.Settings = _genv.Settings or {}
    _genv.Settings.AutoRejoin = _genv.Settings.AutoRejoin or {}
    _genv.Settings.AutoRejoin.Enabled = (val == true)
end

local function setEnabled(val)
    persistEnabled(val)
end

local function toggle()
    local cur = select(1, getAutoRestartConfig())
    setEnabled(not cur)
    return not cur
end

local function findTeleport()
    if ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Teleport') then
        return ReplicatedStorage.Shared.Teleport
    end
    return ReplicatedStorage:FindFirstChild('Teleport')
end

local function watchFinish()
    local plr = Players.LocalPlayer
    while not plr do wait(0.1) plr = Players.LocalPlayer end
    local pg = plr:WaitForChild('PlayerGui')

    local function handleFinish()
        local enabled, delay, towerId = getAutoRestartConfig()
        if not enabled then return end
        warn('AutoRestart: detected finish, restarting in', delay)
        wait(delay)
        local tp = findTeleport()
        if tp and tp:FindFirstChild('StartRaid') then
            pcall(function() tp.StartRaid:FireServer(towerId) end)
        else
            warn('AutoRestart: StartRaid remote not found')
        end
    end

    -- Attach listener to TowerFinish if present
    local mainGui = pg:FindFirstChild('MainGui')
    if mainGui and mainGui:FindFirstChild('TowerFinish') and mainGui.TowerFinish:FindFirstChild('Title') then
        mainGui.TowerFinish.Title.Changed:Connect(handleFinish)
    end

    -- Also watch for MainGui and TowerFinish appearing later
    pg.ChildAdded:Connect(function(child)
        if child and child.Name == 'MainGui' then
            if child:FindFirstChild('TowerFinish') and child.TowerFinish:FindFirstChild('Title') then
                child.TowerFinish.Title.Changed:Connect(handleFinish)
            end
        end
    end)
end

-- start watcher in background
local spawn = function(f) coroutine.wrap(f)() end
spawn(function() watchFinish() end)

return {
    watchFinish = watchFinish,
    getAutoRestartConfig = getAutoRestartConfig,
    isEnabled = isEnabled,
    setEnabled = setEnabled,
    toggle = toggle,
}