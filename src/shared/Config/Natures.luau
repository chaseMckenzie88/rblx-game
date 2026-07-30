--!strict
-- Chakra natures — this game's answer to Devil Fruits. Basic five roll on a
-- weighted table; Kekkei Genkai are the rare chase items.
--
-- Canon advantage cycle: Fire > Wind > Lightning > Earth > Water > Fire

local Types = require(script.Parent.Parent.Types)

local Natures: { [string]: Types.Nature } = {
	Fire = {
		Id = "Fire", Name = "Katon", Kanji = "火遁",
		Rarity = "Common", Color = Color3.fromRGB(255, 94, 40),
		StrongAgainst = "Wind", WeakAgainst = "Water",
	},
	Wind = {
		Id = "Wind", Name = "Futon", Kanji = "風遁",
		Rarity = "Common", Color = Color3.fromRGB(140, 235, 195),
		StrongAgainst = "Lightning", WeakAgainst = "Fire",
	},
	Lightning = {
		Id = "Lightning", Name = "Raiton", Kanji = "雷遁",
		Rarity = "Common", Color = Color3.fromRGB(255, 232, 90),
		StrongAgainst = "Earth", WeakAgainst = "Wind",
	},
	Earth = {
		Id = "Earth", Name = "Doton", Kanji = "土遁",
		Rarity = "Common", Color = Color3.fromRGB(175, 130, 85),
		StrongAgainst = "Water", WeakAgainst = "Lightning",
	},
	Water = {
		Id = "Water", Name = "Suiton", Kanji = "水遁",
		Rarity = "Common", Color = Color3.fromRGB(80, 165, 255),
		StrongAgainst = "Fire", WeakAgainst = "Earth",
	},

	-- Kekkei Genkai — combined natures, no elemental cycle interaction.
	Ice = {
		Id = "Ice", Name = "Hyoton", Kanji = "氷遁",
		Rarity = "Rare", Color = Color3.fromRGB(190, 240, 255),
	},
	Lava = {
		Id = "Lava", Name = "Yoton", Kanji = "熔遁",
		Rarity = "Rare", Color = Color3.fromRGB(255, 120, 30),
	},
	Storm = {
		Id = "Storm", Name = "Ranton", Kanji = "嵐遁",
		Rarity = "Rare", Color = Color3.fromRGB(130, 200, 255),
	},
	Scorch = {
		Id = "Scorch", Name = "Shakuton", Kanji = "灼遁",
		Rarity = "Legendary", Color = Color3.fromRGB(255, 175, 60),
	},
	Explosion = {
		Id = "Explosion", Name = "Bakuton", Kanji = "爆遁",
		Rarity = "Legendary", Color = Color3.fromRGB(255, 80, 120),
	},
	Wood = {
		Id = "Wood", Name = "Mokuton", Kanji = "木遁",
		Rarity = "Mythic", Color = Color3.fromRGB(110, 200, 110),
	},
}

-- Roll weights. Higher = more common. Tune these rather than the rarity labels.
local RollWeights: { [string]: number } = {
	Fire = 200, Wind = 200, Lightning = 200, Earth = 200, Water = 200,
	Ice = 40, Lava = 40, Storm = 40,
	Scorch = 12, Explosion = 12,
	Wood = 2,
}

-- Damage multiplier when attacker's nature counters the defender's.
local ADVANTAGE = 1.25
local DISADVANTAGE = 0.8

local NatureModule = {}

NatureModule.All = Natures
NatureModule.Weights = RollWeights

function NatureModule.get(id: string?): Types.Nature?
	return if id then Natures[id] else nil
end

-- Weighted random roll. Pass a Random for reproducible results in tests.
function NatureModule.roll(rng: Random?): string
	local generator = rng or Random.new()

	local total = 0
	for _, weight in RollWeights do
		total += weight
	end

	local target = generator:NextNumber() * total
	local cursor = 0

	for id, weight in RollWeights do
		cursor += weight
		if target <= cursor then
			return id
		end
	end

	return "Fire" -- unreachable, but keeps the return type honest
end

-- Multiplier to apply to attacker damage based on the elemental cycle.
function NatureModule.matchup(attackerId: string?, defenderId: string?): number
	local attacker = NatureModule.get(attackerId)
	local defender = NatureModule.get(defenderId)
	if not attacker or not defender then
		return 1
	end

	if attacker.StrongAgainst == defender.Id then
		return ADVANTAGE
	elseif attacker.WeakAgainst == defender.Id then
		return DISADVANTAGE
	end
	return 1
end

return NatureModule
