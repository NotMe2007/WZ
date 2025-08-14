
-- Robust AutoDungeon starter
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

-- Wait for local player
local player = Players.LocalPlayer
while not player do wait(0.05) player = Players.LocalPlayer end

-- Wait for Profiles container
local profiles = ReplicatedStorage:FindFirstChild('Profiles')
local tries = 0
while not profiles and tries < 50 do
	wait(0.05)
	profiles = ReplicatedStorage:FindFirstChild('Profiles')
	tries = tries + 1
end
if not profiles then warn('Autodungeon: Profiles folder not found in ReplicatedStorage') return end

-- Find player profile (best-effort)
local profile = profiles:FindFirstChild(player.Name) or profiles:FindFirstChild('NT_Script')
if not profile then warn('Autodungeon: player profile not found') return end

local levelObj = profile:FindFirstChild('Level')
local level = (levelObj and levelObj.Value) or 1

-- Find Teleport remote in a defensive manner
local teleport = nil
if ReplicatedStorage:FindFirstChild('Shared') and ReplicatedStorage.Shared:FindFirstChild('Teleport') then
	teleport = ReplicatedStorage.Shared.Teleport
elseif ReplicatedStorage:FindFirstChild('Teleport') then
	teleport = ReplicatedStorage:FindFirstChild('Teleport')
end

if teleport and teleport:FindFirstChild('StartRaid') and type(teleport.StartRaid.FireServer) == 'function' then
	pcall(function()
		teleport.StartRaid:FireServer(level, 1)
	end)
else
	warn('Autodungeon: StartRaid remote not found or not callable')
end
