--!strict
-- Kill quests. This is now the only route XP takes into a profile from combat —
-- EnemyService reports kills here and pays nothing itself.
--
-- Quests auto-complete on the final kill rather than making you walk back. That
-- matches the genre, and it means a disconnect mid-quest can't eat a reward you
-- already earned. Switch `complete` to require a turn-in at the NPC if you'd
-- rather have the trek.

local Shared = game.ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Quests = require(Shared.Config.Quests)
local QuestGivers = require(Shared.Config.QuestGivers)
local Village = require(Shared.Config.Village)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)

local QuestService = {}

local function notify(player: Player, text: string)
	Remotes.Events.Notify:FireClient(player, { text = text })
end

local function zoneFor(zoneId: string): Village.Zone?
	for _, zone in Village.Zones do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

-- Everything the HUD tracker and the kunai compass need, in one shape. The
-- compass needs real world coordinates, so the quest's zone centre and the
-- giver's id ride along with the progress numbers.
function QuestService.push(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local quest = Quests.get(profile.ActiveQuest)
	local payload = nil

	if quest then
		local zone = zoneFor(quest.ZoneId)
		local giver = QuestGivers.forQuest(quest.Id)

		payload = {
			id = quest.Id,
			name = quest.Name,
			areaName = quest.AreaName,
			targetName = quest.TargetName,
			targetLevel = quest.TargetLevel,
			killCount = quest.KillCount,
			progress = math.min(profile.QuestProgress, quest.KillCount),
			-- Where to go. nil if the zone is missing from the village config, and
			-- the compass simply won't point rather than pointing at the origin.
			zonePosition = if zone then zone.center else nil,
			giverId = if giver then giver.Id else nil,
			giverName = if giver then giver.Name else nil,
		}
	end

	Remotes.Events.QuestUpdated:FireClient(player, { active = payload })
end

-- XP a quest pays. Computed at turn-in so the anti-farm penalty uses the level
-- the player actually finished at, not the one they accepted at.
function QuestService.rewardFor(quest: Types.Quest, playerLevel: number): number
	if quest.XPReward then
		return quest.XPReward
	end

	local perKill = Formulas.xpReward(quest.TargetLevel, playerLevel)
	return math.floor(perKill * quest.KillCount * GameConfig.QuestCompletionBonus)
end

function QuestService.accept(player: Player, questId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local quest = Quests.get(questId)
	if not quest then
		return
	end

	-- Server-side gate. The client's list is a convenience, not the authority.
	if profile.Level < quest.RequiredLevel then
		notify(player, `Requires level {quest.RequiredLevel}`)
		return
	end

	if not quest.Repeatable and (profile.QuestsCompleted[quest.Id] or 0) > 0 then
		notify(player, "You've already done that one.")
		return
	end

	if profile.ActiveQuest == quest.Id then
		notify(player, "Already on that quest.")
		return
	end

	profile.ActiveQuest = quest.Id
	profile.QuestProgress = 0

	notify(player, `{quest.Name} — defeat {quest.KillCount} {quest.TargetName}`)
	QuestService.push(player)
	ProgressionService.push(player)
end

function QuestService.abandon(player: Player)
	local profile = DataService.get(player)
	if not profile or not profile.ActiveQuest then
		return
	end

	profile.ActiveQuest = nil
	profile.QuestProgress = 0

	notify(player, "Quest abandoned")
	QuestService.push(player)
	ProgressionService.push(player)
end

local function complete(player: Player, profile: Types.Profile, quest: Types.Quest)
	profile.ActiveQuest = nil
	profile.QuestProgress = 0
	profile.QuestsCompleted[quest.Id] = (profile.QuestsCompleted[quest.Id] or 0) + 1
	profile.Ryo += quest.RyoReward

	local xp = QuestService.rewardFor(quest, profile.Level)

	notify(player, `{quest.Name} complete  ·  +{xp} XP  ·  +{quest.RyoReward} Ryo`)

	-- awardXP pushes the profile and handles level-ups, so it goes last.
	ProgressionService.awardXP(player, xp)
	QuestService.push(player)
end

-- Called by EnemyService on every kill. Silently ignores kills that don't match
-- the active quest, so wandering into the wrong area just wastes your time.
function QuestService.reportKill(player: Player, targetName: string, _targetLevel: number)
	local profile = DataService.get(player)
	if not profile or not profile.ActiveQuest then
		return
	end

	local quest = Quests.get(profile.ActiveQuest)
	if not quest or quest.TargetName ~= targetName then
		return
	end

	profile.QuestProgress += 1

	if profile.QuestProgress >= quest.KillCount then
		complete(player, profile, quest)
	else
		notify(player, `{quest.TargetName}  {profile.QuestProgress}/{quest.KillCount}`)
		QuestService.push(player)
	end
end

function QuestService.start()
	Remotes.Events.AcceptQuest.OnServerEvent:Connect(function(player, payload)
		if type(payload) == "table" and type(payload.id) == "string" then
			QuestService.accept(player, payload.id)
		end
	end)

	Remotes.Events.AbandonQuest.OnServerEvent:Connect(function(player)
		QuestService.abandon(player)
	end)
end

return QuestService
