local game = rawget(_G, 'game') or error('game missing')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local workspace = game:GetService('Workspace')

local function wait(sec)
    sec = tonumber(sec)
    if sec and sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do RunService.Heartbeat:Wait() end
    else
        RunService.Heartbeat:Wait()
    end
end

local firetouchinterest = rawget(_G, 'firetouchinterest') or function() end

-- wait for mission objects
while not workspace:FindFirstChild('MissionObjects') do wait() end

workspace.MissionObjects.DescendantAdded:Connect(function(v)
    local root = Players.LocalPlayer and Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    if not root then return end
    if type(firetouchinterest) == 'function' then
        pcall(function()
            firetouchinterest(root, v.Parent, 0)
            wait(0.25)
            firetouchinterest(root, v.Parent, 1)
        end)
    end
    print(v)
end)