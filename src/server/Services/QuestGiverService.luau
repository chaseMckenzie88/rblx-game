--!strict
-- Spawns every quest giver in the QuestGivers config and handles their prompts.
--
-- First interaction plays that giver's greeting as a dialogue box, and the board
-- opens once it's dismissed. Every later interaction goes straight to the board —
-- the greeting is still there as the board's subtitle, so nothing is lost.
--
-- Accepting still round-trips through AcceptQuest, which QuestService
-- re-validates. The client's list is a convenience, never the authority.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local QuestGivers = require(Shared.Config.QuestGivers)
local Quests = require(Shared.Config.Quests)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local NPCBuilder = require(script.Parent.NPCBuilder)
local QuestService = require(script.Parent.QuestService)

local QuestGiverService = {}

-- Who has heard whom. Session-scoped rather than saved to the profile: hearing a
-- greeting again after a rejoin is harmless, and it keeps the save format clean.
local greeted: { [Player]: { [string]: boolean } } = {}

local function boardPayload(player: Player, giver: QuestGivers.Giver)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	local rows = {}

	-- Only this giver's quests, in the order the config lists them, so the board
	-- reads the same way every time.
	for _, questId in giver.QuestIds do
		local quest = Quests.get(questId)
		if not quest then
			continue
		end

		local locked = profile.Level < quest.RequiredLevel
		local doneOnce = not quest.Repeatable and (profile.QuestsCompleted[quest.Id] or 0) > 0

		table.insert(rows, {
			id = quest.Id,
			name = quest.Name,
			areaName = quest.AreaName,
			targetName = quest.TargetName,
			targetLevel = quest.TargetLevel,
			killCount = quest.KillCount,
			requiredLevel = quest.RequiredLevel,
			ryoReward = quest.RyoReward,
			xpReward = QuestService.rewardFor(quest, profile.Level),
			repeatable = quest.Repeatable,
			active = profile.ActiveQuest == quest.Id,
			timesCompleted = profile.QuestsCompleted[quest.Id] or 0,
			locked = locked,
			completedOnce = doneOnce,
		})
	end

	return {
		giver = {
			name = giver.Name,
			title = giver.Title,
			greeting = giver.Greeting,
			levelMin = giver.LevelMin,
			levelMax = giver.LevelMax,
		},
		quests = rows,
	}
end

local function onTriggered(giver: QuestGivers.Giver, player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local heard = greeted[player]
	if not heard then
		heard = {}
		greeted[player] = heard
	end

	local payload = boardPayload(player, giver)
	if not payload then
		return
	end

	if not heard[giver.Id] then
		heard[giver.Id] = true
		Remotes.Events.ShowDialogue:FireClient(player, {
			name = giver.Name,
			title = giver.Title,
			text = giver.Greeting,
			-- The client opens the board itself once the line is dismissed, so the
			-- first meeting reads as a conversation rather than two popups at once.
			thenOpenBoard = payload,
		})
		return
	end

	Remotes.Events.OpenQuestBoard:FireClient(player, payload)
end

function QuestGiverService.start()
	for _, giver in QuestGivers.All do
		local npc = NPCBuilder.build({
			name = giver.Id,
			displayName = giver.Name,
			actionText = "Talk",
			robeColor = giver.RobeColor,
			titleColor = giver.TitleColor,
			markerName = giver.MarkerName,
			fallbackPosition = giver.FallbackPosition,
		})

		npc.prompt.ObjectText = `{giver.Name}  ·  Lv {giver.LevelMin}-{giver.LevelMax}`

		npc.prompt.Triggered:Connect(function(player)
			onTriggered(giver, player)
		end)

		print(`[QuestGiverService] {giver.Name} placed`)
	end

	Players.PlayerRemoving:Connect(function(player)
		greeted[player] = nil
	end)
end

return QuestGiverService
