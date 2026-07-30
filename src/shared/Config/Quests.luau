--!strict
-- Area kill quests. One entry per area; the quest giver offers whichever ones
-- the player's level allows.
--
-- KillCount is 5 nearly everywhere — that's the baseline rhythm. Special areas
-- (bosses, event zones) override both the count and the reward.
--
-- XPReward left nil means "compute it at turn-in from the target's level and the
-- player's level", which keeps Formulas.xpReward's anti-farming penalty in play.
-- Set it explicitly only when an area should pay a fixed, hand-tuned amount.

local Types = require(script.Parent.Parent.Types)
local GameConfig = require(script.Parent.GameConfig)

local COUNT = GameConfig.DefaultQuestKillCount

local Quests: { [string]: Types.Quest } = {
	-- The tutorial quest. Straw training dolls rather than live enemies — Ibiki is
	-- testing you, not sending a fresh genin after bandits. Set in the Academy
	-- courtyard, a few steps from where the player spawns.
	AcademyCourtyard = {
		Id = "AcademyCourtyard",
		Name = "Target Practice",
		AreaName = "Academy Courtyard",
		ZoneId = "AcademyCourtyard",
		TargetName = "Training Doll",
		TargetLevel = 1,
		KillCount = COUNT,
		RequiredLevel = 1,
		XPReward = nil,
		RyoReward = 30,
		Repeatable = true,
	},

	TrainingGrounds = {
		Id = "TrainingGrounds",
		Name = "Sparring Practice",
		AreaName = "Training Grounds",
		ZoneId = "TrainingGrounds",
		TargetName = "Rogue Genin",
		TargetLevel = 10,
		KillCount = COUNT,
		RequiredLevel = 8,
		XPReward = nil,
		RyoReward = 120,
		Repeatable = true,
	},

	ForestOfDeath = {
		Id = "ForestOfDeath",
		Name = "Cull the Missing-Nin",
		AreaName = "Forest of Death",
		ZoneId = "ForestOfDeath",
		TargetName = "Missing-Nin",
		TargetLevel = 25,
		KillCount = COUNT,
		RequiredLevel = 20,
		XPReward = nil,
		RyoReward = 400,
		Repeatable = true,
	},

	-- Special area: fewer kills, hand-tuned reward, not repeatable.
	AkatsukiScout = {
		Id = "AkatsukiScout",
		Name = "The Scout in Red Clouds",
		AreaName = "Akatsuki Outpost",
		ZoneId = "AkatsukiOutpost",
		TargetName = "Akatsuki Scout",
		TargetLevel = 50,
		KillCount = 1,
		RequiredLevel = 45,
		XPReward = 90000,
		RyoReward = 2500,
		Repeatable = false,
	},
}

local QuestModule = {}

QuestModule.All = Quests

function QuestModule.get(id: string?): Types.Quest?
	return if id then Quests[id] else nil
end

-- Quests this player is high enough level for, and hasn't already finished a
-- one-shot version of. Sorted by level so the giver lists them sensibly.
function QuestModule.availableFor(level: number, completed: { [string]: number }): { Types.Quest }
	local list: { Types.Quest } = {}

	for _, quest in Quests do
		if level < quest.RequiredLevel then
			continue
		end
		if not quest.Repeatable and (completed[quest.Id] or 0) > 0 then
			continue
		end
		table.insert(list, quest)
	end

	table.sort(list, function(a, b)
		return a.RequiredLevel < b.RequiredLevel
	end)

	return list
end

return QuestModule
