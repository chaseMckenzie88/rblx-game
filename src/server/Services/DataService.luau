--!strict
-- Profile persistence. Deliberately compact rather than a full ProfileService,
-- but it covers the things that actually lose player data: failed loads being
-- treated as "new player", saves that never retry, and shutdown without a flush.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Types = require(game.ReplicatedStorage.Shared.Types)
local GameConfig = require(game.ReplicatedStorage.Shared.Config.GameConfig)

local DataService = {}

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local profiles: { [Player]: Types.Profile } = {}

-- Studio has no DataStore access unless API services are enabled, and even
-- then you rarely want test play polluting live data.
local useDataStore = not RunService:IsStudio()

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- Fill in fields added since this profile was written. Without this, adding a
-- field to defaultProfile() would read as nil for every existing player.
local function migrate(loaded: any): Types.Profile
	local template = GameConfig.defaultProfile()

	if type(loaded) ~= "table" then
		return template
	end

	for field, default in template :: any do
		if loaded[field] == nil then
			loaded[field] = default
		end
	end

	-- Stats is nested, so it needs the same treatment one level down.
	for stat, default in template.Stats :: any do
		if loaded.Stats[stat] == nil then
			loaded.Stats[stat] = default
		end
	end

	loaded.DataVersion = GameConfig.DataVersion
	return loaded :: Types.Profile
end

local function retry<T>(label: string, attempt: () -> T): (boolean, T?)
	for tries = 1, GameConfig.SaveRetries do
		local ok, result = pcall(attempt)
		if ok then
			return true, result
		end
		warn(`[DataService] {label} failed (attempt {tries}): {result}`)
		if tries < GameConfig.SaveRetries then
			task.wait(GameConfig.SaveRetryDelay * tries)
		end
	end
	return false, nil
end

function DataService.load(player: Player): Types.Profile
	if not useDataStore then
		local profile = GameConfig.defaultProfile()
		profiles[player] = profile
		return profile
	end

	local ok, loaded = retry(`load {player.Name}`, function()
		return store:GetAsync(key(player))
	end)

	if not ok then
		-- Critical: never hand back a blank profile after a failed read, or the
		-- next autosave overwrites a real save with an empty one. Kick instead.
		player:Kick("Couldn't load your ninja data. Please rejoin — your progress is safe.")
		local placeholder = GameConfig.defaultProfile()
		profiles[player] = placeholder
		return placeholder
	end

	local profile = migrate(loaded)
	profiles[player] = profile
	return profile
end

function DataService.get(player: Player): Types.Profile?
	return profiles[player]
end

function DataService.save(player: Player): boolean
	local profile = profiles[player]
	if not profile or not useDataStore then
		return true
	end

	profile.LastSeen = os.time()

	local ok = retry(`save {player.Name}`, function()
		store:UpdateAsync(key(player), function()
			return profile
		end)
		return true
	end)

	return ok
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player] = nil
end

function DataService.start()
	Players.PlayerRemoving:Connect(DataService.release)

	-- Autosave loop, staggered so 30 players don't all write in the same frame.
	task.spawn(function()
		while task.wait(GameConfig.AutosaveInterval) do
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.save, player)
				task.wait(0.2)
			end
		end
	end)

	-- Roblox gives ~30s on shutdown. Flush everyone in parallel and wait.
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end

		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	if not useDataStore then
		warn("[DataService] Studio detected — using in-memory profiles, nothing persists.")
	end
end

return DataService
