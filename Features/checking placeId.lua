local game = rawget(_G, 'game') or { PlaceId = 0 }

local dungeonId = {
	-- world 1
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
	[6075085184] = 'Atlantis Tower',
    [7071564842] = 'Mezuvian Tower'
}


local lobbyId = {
	[2727067538] = 'Main menu',
	[4310463616] = 'World 1',
	[4310463940] = 'World 2',
	[4465987684] = 'World 3',
	[4646472003] = 'World 4',
	[5703355191] = 'World 5',
	[6075083204] = 'World 6',
	[6847035264] = 'World 7',
}

local function findInMap(map, placeId)
	for id, name in pairs(map) do
		if placeId == id then return true, name end
	end
	return false, nil
end

local function isLobby(placeId)
	return findInMap(lobbyId, placeId)
end

local function isDungeon(placeId)
	return findInMap(dungeonId, placeId)
end

local function isTower(placeId)
	return findInMap(towerId, placeId)
end

-- convenient detection using current game.PlaceId
local function detectCurrent()
	local pid = game and game.PlaceId or 0
	local inLobby, lobbyName = isLobby(pid)
	if inLobby then return 'lobby', lobbyName end
	local inDungeon, dungeonName = isDungeon(pid)
	if inDungeon then return 'dungeon', dungeonName end
	local inTower, towerName = isTower(pid)
	if inTower then return 'tower', towerName end
	return 'unknown', nil
end

local kind, name = detectCurrent()

local M = {
	isLobby = isLobby,
	isDungeon = isDungeon,
	isTower = isTower,
	findInMap = findInMap,
	detectCurrent = detectCurrent,
	currentKind = kind,
	currentName = name,
	dungeonId = dungeonId,
	towerId = towerId,
	lobbyId = lobbyId,
}

return M