--!strict
-- Quest givers. Each one owns a level band and a list of quests, so the mission
-- board can use one identical layout everywhere: who's talking, what level range
-- they serve, then the quests.
--
-- Adding an NPC is a table entry — QuestGiverService spawns every giver in here,
-- so no code changes are needed to populate the village.

local Types = require(script.Parent.Parent.Types)
local Village = require(script.Parent.Village)

-- Ibiki stands just inside the courtyard gate, derived from the Academy layout
-- rather than written down as coordinates, so he can't end up standing in the
-- fence if the precinct moves. 14 studs in puts him clear of the ring the
-- training dolls scatter across.
local IbikiPosition = (
	Village.Academy.base
	* CFrame.new(0, 3.5, -(Village.Academy.depth / 2 + Village.Academy.courtyardGap + 14))
).Position

export type Giver = {
	Id: string,
	Name: string,
	Title: string,
	-- Said once, the first time a player interacts. Also shown as the board's
	-- subtitle so it's always readable, not just on the first click.
	Greeting: string,
	LevelMin: number,
	LevelMax: number,
	QuestIds: { string },
	-- Drop a part with this name in Workspace to place them by hand.
	MarkerName: string,
	FallbackPosition: Vector3,
	RobeColor: Color3,
	TitleColor: Color3,
}

-- Ibiki stands in the Academy courtyard, where a new player spawns next to him.
-- The other three share the village plaza, so every later tier of work is still
-- findable in one place. Move any of them by dropping a part with the matching
-- MarkerName in Workspace.
--
-- Only Ibiki's line is yours — the other three are placeholders written to match
-- his cadence. Replace them freely.
local Givers: { [string]: Giver } = {
	Ibiki = {
		Id = "Ibiki",
		Name = "Ibiki Morino",
		Title = "Chunin Exam Proctor",
		Greeting = "Hello, I'm Ibiki Morino. If you want to compete in the Chunin Exams, you need to show me what you got.",
		LevelMin = 0,
		LevelMax = 5,
		QuestIds = { "AcademyCourtyard" },
		MarkerName = "IbikiNPC",
		FallbackPosition = IbikiPosition,
		RobeColor = Color3.fromRGB(60, 72, 58),
		TitleColor = Color3.fromRGB(180, 210, 160),
	},

	Guy = {
		Id = "Guy",
		Name = "Might Guy",
		Title = "Taijutsu Specialist",
		Greeting = "The springtime of youth burns in you! Show me that fire out on the training ground.",
		LevelMin = 8,
		LevelMax = 15,
		QuestIds = { "TrainingGrounds" },
		MarkerName = "GuyNPC",
		FallbackPosition = Vector3.new(-55, 3.5, 300),
		RobeColor = Color3.fromRGB(46, 88, 62),
		TitleColor = Color3.fromRGB(150, 230, 165),
	},

	Anko = {
		Id = "Anko",
		Name = "Anko Mitarashi",
		Title = "Second Exam Proctor",
		Greeting = "So you want the Forest of Death. Cute. Thin out the missing-nin in there and I'll believe you.",
		LevelMin = 20,
		LevelMax = 30,
		QuestIds = { "ForestOfDeath" },
		MarkerName = "AnkoNPC",
		FallbackPosition = Vector3.new(88, 3.5, 238),
		RobeColor = Color3.fromRGB(112, 78, 96),
		TitleColor = Color3.fromRGB(232, 168, 196),
	},

	Kakashi = {
		Id = "Kakashi",
		Name = "Kakashi Hatake",
		Title = "Jonin, Team Seven",
		Greeting = "There's a scout in red clouds north of the village. Don't engage unless you're ready — I mean it.",
		LevelMin = 45,
		LevelMax = 60,
		QuestIds = { "AkatsukiScout" },
		MarkerName = "KakashiNPC",
		FallbackPosition = Vector3.new(-88, 3.5, 238),
		RobeColor = Color3.fromRGB(72, 82, 100),
		TitleColor = Color3.fromRGB(196, 210, 235),
	},
}

local GiverModule = {}

GiverModule.All = Givers

function GiverModule.get(id: string?): Giver?
	return if id then Givers[id] else nil
end

-- The giver who hands out a given quest, if any. Lets a quest render its source
-- without every quest entry having to repeat the giver's name.
function GiverModule.forQuest(questId: string): Giver?
	for _, giver in Givers do
		for _, id in giver.QuestIds do
			if id == questId then
				return giver
			end
		end
	end
	return nil
end

return GiverModule
