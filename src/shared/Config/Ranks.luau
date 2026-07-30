--!strict
-- Ninja ranks. Purely cosmetic progression markers layered over level —
-- gate content on level, not rank, so rebalancing ranks breaks nothing.

local Types = require(script.Parent.Parent.Types)

local Ranks: { Types.Rank } = {
	{ Name = "Academy Student", MinLevel = 1,   Color = Color3.fromRGB(170, 170, 170) },
	{ Name = "Genin",           MinLevel = 15,  Color = Color3.fromRGB(120, 200, 120) },
	{ Name = "Chunin",          MinLevel = 60,  Color = Color3.fromRGB(90, 160, 255) },
	{ Name = "Jonin",           MinLevel = 150, Color = Color3.fromRGB(180, 120, 255) },
	{ Name = "ANBU",            MinLevel = 300, Color = Color3.fromRGB(255, 150, 60) },
	{ Name = "Sannin",          MinLevel = 500, Color = Color3.fromRGB(255, 90, 90) },
	{ Name = "Kage",            MinLevel = 800, Color = Color3.fromRGB(255, 215, 0) },
}

local RankModule = {}

RankModule.All = Ranks

function RankModule.forLevel(level: number): Types.Rank
	local current = Ranks[1]
	for _, rank in Ranks do
		if level >= rank.MinLevel then
			current = rank
		else
			break -- list is sorted, so nothing further can match
		end
	end
	return current
end

-- Level at which the player earns their next rank, or nil at max rank.
function RankModule.nextRankLevel(level: number): number?
	for _, rank in Ranks do
		if level < rank.MinLevel then
			return rank.MinLevel
		end
	end
	return nil
end

return RankModule
