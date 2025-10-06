local game = rawget(_G, 'game') or error('game missing')
local Lighting = game:GetService('Lighting')

local presets = {
    default = {
        MoonTextureId = 'rbxassetid://3176877317',
        SkyboxBk = 'rbxassetid://3176877317',
        SkyboxDn = 'rbxassetid://3176877696',
        SkyboxFt = 'rbxassetid://3176878020',
        SkyboxLf = 'rbxassetid://3176878336',
        SkyboxRt = 'rbxassetid://3176878576',
        SkyboxUp = 'rbxassetid://3176878816',
        SunTextureId = 'rbxassetid://1084351190',
    },
}

local function applyToSky(skyObj, preset)
    if not skyObj or type(preset) ~= 'table' then return false end
    for k, v in pairs(preset) do
        pcall(function()
            if skyObj[k] ~= nil then skyObj[k] = v end
        end)
    end
    return true
end

local function applyPreset(name)
    local preset = presets[name]
    if not preset then return false end
    for _, child in ipairs(Lighting:GetChildren()) do
        if child and type(child.IsA) == 'function' and child:IsA('Sky') then
            applyToSky(child, preset)
        end
    end
    return true
end

return {
    presets = presets,
    applyPreset = applyPreset,
    applyToSky = applyToSky,
}