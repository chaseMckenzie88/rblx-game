--!strict
-- Server entry point. Load order matters: data must be ready before anything
-- reads a profile, so player joins are handled here rather than in each service.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.Services.DataService)
local ProgressionService = require(script.Parent.Services.ProgressionService)
local ChakraService = require(script.Parent.Services.ChakraService)
local MovementService = require(script.Parent.Services.MovementService)
local QuestService = require(script.Parent.Services.QuestService)
local EnemyService = require(script.Parent.Services.EnemyService)
local CombatService = require(script.Parent.Services.CombatService)
local NatureNPCService = require(script.Parent.Services.NatureNPCService)
local QuestGiverService = require(script.Parent.Services.QuestGiverService)

local Atmosphere = require(script.Parent.World.Atmosphere)
local VillageService = require(script.Parent.World.VillageService)

-- Each subsystem is started in isolation. Without this, one error anywhere -- a
-- read-only property, a bad config entry -- aborts the whole script and you get a
-- completely empty game with one red line in Output, which is a miserable thing
-- to debug. This way the failure is named and everything else still comes up.
local function startUp(label: string, start: () -> ())
	local ok, err = pcall(start)
	if not ok then
		warn(`[Bootstrap] {label} FAILED: {err}`)
	end
	return ok
end

startUp("DataService", DataService.start)
startUp("ProgressionService", ProgressionService.start)
startUp("ChakraService", ChakraService.start)
startUp("MovementService", MovementService.start)
startUp("QuestService", QuestService.start)

-- The world goes up before anything that stands on it: enemies and NPCs read
-- their positions from village zones, so the geometry has to exist first.
startUp("Atmosphere", Atmosphere.start)
startUp("VillageService", VillageService.start)

-- Then combat. Kills route through QuestService, which pays out via
-- ProgressionService, so both are already listening by here.
startUp("EnemyService", EnemyService.start)
startUp("CombatService", CombatService.start)
startUp("NatureNPCService", NatureNPCService.start)
startUp("QuestGiverService", QuestGiverService.start)

local function onPlayerAdded(player: Player)
	local profile = DataService.load(player)

	-- Roblox's built-in leaderboard. Cheap wins for a game like this.
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = profile.Level
	levelValue.Parent = stats

	local rankValue = Instance.new("StringValue")
	rankValue.Name = "Rank"
	rankValue.Value = Ranks.forLevel(profile.Level).Name
	rankValue.Parent = stats

	stats.Parent = player

	-- Keep leaderstats in step with the profile without every service
	-- having to remember to update it.
	task.spawn(function()
		while player.Parent do
			local current = DataService.get(player)
			if current then
				levelValue.Value = current.Level
				rankValue.Value = Ranks.forLevel(current.Level).Name
				current.Playtime += 1
			end
			task.wait(1)
		end
	end)

	ProgressionService.push(player)
	-- Restores the tracker after a rejoin mid-quest.
	QuestService.push(player)
end

-- Players who joined before this script finished running still need handling.
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- Test hook for the HUD's +XP button. Only wired up in Studio — in a live
-- game the remote exists but nothing listens, so firing it does nothing.
if RunService:IsStudio() then
	Remotes.Events.DebugAwardXP.OnServerEvent:Connect(function(player, amount)
		ProgressionService.awardXP(player, math.clamp(tonumber(amount) or 500, 1, 100000))
	end)
	warn("[Bootstrap] Studio detected — debug XP remote is live.")
end

print(`[{GameConfig.GameName}] server ready`)
