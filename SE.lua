-- SE.lua - Soul Eater Quest Automation
-- Automates hero delivery quests by interacting with radiant NPCs

local game = rawget(_G, 'game') or error('game global missing')
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Workspace = game:GetService('Workspace')

-- Wait function
local function wait(sec)
    sec = tonumber(sec) or 0
    if sec > 0 then
        local t0 = os.clock()
        while os.clock() - t0 < sec do RunService.Heartbeat:Wait() end
    else
        RunService.Heartbeat:Wait()
    end
end

-- Get player and character
local function getPlayer()
    local plr = Players.LocalPlayer
    while not plr do
        wait(0.05)
        plr = Players.LocalPlayer
    end
    
    local cha = plr.Character or plr.CharacterAdded:Wait()
    local hrp = cha:WaitForChild('HumanoidRootPart')
    local humanoid = cha:FindFirstChild('Humanoid')
    
    return plr, cha, hrp, humanoid
end

-- Teleport player to a position or CFrame
local function teleportTo(cframe)
    local plr, cha, hrp, humanoid = getPlayer()
    if hrp and cframe then
        hrp.CFrame = cframe
        wait(0.5)
    end
end

-- Fire touch interest for interaction
local firetouchinterest = rawget(_G, 'firetouchinterest')
local getconnections = rawget(_G, 'getconnections')

local function interactWithPart(part)
    local plr, cha, hrp, humanoid = getPlayer()
    if not part or not hrp then return end
    
    pcall(function()
        if firetouchinterest and type(firetouchinterest) == 'function' then
            firetouchinterest(hrp, part, 0)
            wait(0.25)
            firetouchinterest(hrp, part, 1)
        end
    end)
end

-- Click on a GUI element
local function clickButton(button)
    if not button then return end
    
    pcall(function()
        if button:IsA('GuiButton') or button:IsA('TextButton') or button:IsA('ImageButton') then
            if getconnections and type(getconnections) == 'function' then
                for _, connection in pairs(getconnections(button.MouseButton1Click)) do
                    connection:Fire()
                end
            end
        end
    end)
end

-- Main quest automation function
local function doHeroDeliveryQuest()
    local plr, cha, hrp, humanoid = getPlayer()
    
    -- Wait for radiantNpcs to exist
    while not Workspace:FindFirstChild('radiantNpcs') do
        warn('Waiting for radiantNpcs...')
        wait(1)
    end
    
    local radiantNpcs = Workspace.radiantNpcs
    
    -- Step 1: Teleport to heroDelivery NPC
    if radiantNpcs:FindFirstChild('heroDelivery') then
        local heroDelivery = radiantNpcs.heroDelivery
        
        warn('Teleporting to heroDelivery NPC...')
        if heroDelivery:FindFirstChild('HumanoidRootPart') then
            teleportTo(heroDelivery.HumanoidRootPart.CFrame)
        elseif heroDelivery.PrimaryPart then
            teleportTo(heroDelivery.PrimaryPart.CFrame)
        end
        
        wait(0.5)
        
        -- Interact with heroDelivery NPC
        if heroDelivery:FindFirstChild('Detect') then
            warn('Interacting with heroDelivery...')
            interactWithPart(heroDelivery.Detect)
        end
        
        wait(1)
    end
    
    -- Step 2: Get the 21st child (delivery point) and teleport
    local children = radiantNpcs:GetChildren()
    if #children >= 21 then
        local deliveryPoint = children[21]
        
        warn('Teleporting to delivery point:', deliveryPoint.Name)
        if deliveryPoint:IsA('Model') then
            if deliveryPoint:FindFirstChild('HumanoidRootPart') then
                teleportTo(deliveryPoint.HumanoidRootPart.CFrame)
            elseif deliveryPoint.PrimaryPart then
                teleportTo(deliveryPoint.PrimaryPart.CFrame)
            end
        elseif deliveryPoint:IsA('Part') then
            teleportTo(deliveryPoint.CFrame)
        end
        
        wait(0.5)
        
        -- Step 3: Interact with delivery NPC
        if deliveryPoint:FindFirstChild('Detect') then
            warn('Interacting with delivery NPC...')
            interactWithPart(deliveryPoint.Detect)
        end
        
        wait(1)
    end
    
    -- Step 4: Accept quest (look for quest GUI)
    pcall(function()
        local playerGui = plr:WaitForChild('PlayerGui')
        
        -- Try to find and click accept button in common locations
        for _, gui in pairs(playerGui:GetDescendants()) do
            if gui:IsA('TextButton') or gui:IsA('ImageButton') then
                local text = gui.Text or gui.Name or ''
                if text:lower():match('accept') or text:lower():match('quest') then
                    warn('Accepting quest...')
                    clickButton(gui)
                    wait(1)
                    break
                end
            end
        end
    end)
    
    -- Step 5: Teleport to completion location
    -- Try to find completion marker
    pcall(function()
        for _, child in pairs(radiantNpcs:GetChildren()) do
            if child.Name:lower():match('complete') or child.Name:lower():match('finish') or child.Name:lower():match('deliver') then
                warn('Teleporting to completion location:', child.Name)
                if child:IsA('Model') then
                    if child:FindFirstChild('HumanoidRootPart') then
                        teleportTo(child.HumanoidRootPart.CFrame)
                    elseif child.PrimaryPart then
                        teleportTo(child.PrimaryPart.CFrame)
                    end
                elseif child:IsA('Part') then
                    teleportTo(child.CFrame)
                end
                
                wait(0.5)
                
                -- Step 6: Interact with completion point
                if child:FindFirstChild('Detect') then
                    warn('Interacting with completion point...')
                    interactWithPart(child.Detect)
                end
                
                wait(1)
                break
            end
        end
    end)
    
    -- Step 7: Click deliver button
    pcall(function()
        local playerGui = plr:WaitForChild('PlayerGui')
        
        for _, gui in pairs(playerGui:GetDescendants()) do
            if gui:IsA('TextButton') or gui:IsA('ImageButton') then
                local text = gui.Text or gui.Name or ''
                if text:lower():match('deliver') or text:lower():match('complete') or text:lower():match('turn') then
                    warn('Clicking deliver button...')
                    clickButton(gui)
                    wait(1)
                    break
                end
            end
        end
    end)
    
    warn('Quest automation complete!')
end

-- Run the quest automation
local success, error = pcall(doHeroDeliveryQuest)
if not success then
    warn('Error in SE.lua:', error)
end
