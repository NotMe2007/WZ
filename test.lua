-- test.lua — guarded hooks/wrappers for Drops.SellItems and Mobs.SpawnMob
-- Goals: avoid shadowed locals, guard missing APIs, and prevent runtime errors from unhandled nils.

local function safeRequire(path)
    local ok, res = pcall(function() return require(path) end)
    if ok then return res end
    warn("safeRequire failed for", path)
    return nil
end

-- safe access to globals for editors and Roblox runtime
local _G = _G
local hookfunction = rawget(_G, 'hookfunction')
local unpack = rawget(_G, 'unpack') or table.unpack
local ReplicatedStorage
do
    local g = rawget(_G, 'game')
    if g and g.GetService then
        ReplicatedStorage = g:GetService('ReplicatedStorage')
    end
end

-- DROPS -> SellItems
local Drops = safeRequire(ReplicatedStorage.Shared and ReplicatedStorage.Shared.Drops)
if Drops then
    local target = Drops.SellItems
    if target then
        -- prefer hookfunction when available, otherwise wrap in a safe proxy
        if type(hookfunction) == 'function' then
            local captured_original
            captured_original = hookfunction(target, function(a,b,c,d,e)
                pcall(function()
                    print("SellItems called with:")
                    print("a:", a)
                    print("b:", b)
                    print("c:", c)
                    -- print lengths when possible
                    if type(a) == 'table' then print('#a =', #a) end
                    if type(b) == 'table' then print('#b =', #b) end
                    if type(c) == 'table' then print('#c =', #c) end
                    -- if tables, iterate safely
                    if type(a) == 'table' then for k,v in pairs(a) do print('a[',k,'] =', v) end end
                end)
                -- call original inside pcall to avoid breaking flow
                local ok2, res = pcall(function() return captured_original(a,b,c,d,e) end)
                if not ok2 then warn('SellItems hook original failed') end
                return res
            end)
            -- original is the original function returned by hookfunction (not used here)
        else
            -- fallback: replace function with wrapper while preserving original
            local original = target
            Drops.SellItems = function(a,b,c,d,e)
                pcall(function()
                    print("SellItems called (wrapped):", a,b,c)
                    if type(a) == 'table' then print('#a =', #a) end
                end)
                local ok2, res = pcall(function() return original(a,b,c,d,e) end)
                if not ok2 then warn('Wrapped SellItems original failed') end
                return res
            end
        end
    else
        warn('Drops.SellItems not found')
    end
else
    warn('Drops module missing; skipping SellItems hook')
end

-- MOBS -> SpawnMob
local MobsModule = safeRequire(ReplicatedStorage.Shared and ReplicatedStorage.Shared.Mobs)
if MobsModule then
    local target2 = MobsModule.SpawnMob
    if target2 then
        if type(hookfunction) == 'function' then
            local captured_original2
            captured_original2 = hookfunction(target2, function(...)
                local args = {...}
                pcall(function()
                    print('SpawnMob called with args:')
                    for i,v in ipairs(args) do print(i, v) end
                end)
                local ok, res = pcall(function() return captured_original2(unpack(args)) end)
                if not ok then warn('SpawnMob hook original failed') end
                return res
            end)
        else
            local original2 = target2
            MobsModule.SpawnMob = function(...)
                local args = {...}
                pcall(function()
                    print('SpawnMob (wrapped) args:')
                    for i,v in ipairs(args) do print(i, v) end
                end)
                local ok, res = pcall(function() return original2(unpack(args)) end)
                if not ok then warn('Wrapped SpawnMob original failed') end
                return res
            end
        end
    else
        warn('MobsModule.SpawnMob not found')
    end
else
    warn('Mobs module missing; skipping SpawnMob hook')
end