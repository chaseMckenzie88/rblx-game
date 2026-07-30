--!strict
-- Pure functions: level/stats in, numbers out. No state, no services, so both
-- the server and the client HUD can call these and always agree.

local Types = require(script.Parent.Types)
local GameConfig = require(script.Parent.Config.GameConfig)

local Formulas = {}

-- XP required to advance from `level` to `level + 1`.
function Formulas.xpForNextLevel(level: number): number
	if level >= GameConfig.MaxLevel then
		return math.huge
	end
	local curve = GameConfig.XPCurve
	return math.floor(curve.Base * (level ^ curve.Exponent))
end

-- Total XP needed to reach `level` from scratch. Used by leaderboards and
-- for sanity-checking a loaded profile.
function Formulas.totalXPForLevel(level: number): number
	local total = 0
	for n = 1, level - 1 do
		total += Formulas.xpForNextLevel(n)
	end
	return total
end

function Formulas.derive(profile: Types.Profile): Types.Derived
	local stats = profile.Stats
	local level = profile.Level

	local walkSpeed = math.min(
		GameConfig.BaseWalkSpeed + level * GameConfig.WalkSpeedPerLevel,
		GameConfig.MaxWalkSpeed
	)

	return {
		MaxHealth = math.floor(
			GameConfig.BaseHealth
				+ level * GameConfig.HealthPerLevel
				+ stats.Defense * GameConfig.HealthPerDefensePoint
		),
		MaxChakra = math.floor(
			GameConfig.BaseChakra + stats.Chakra * GameConfig.ChakraPerChakraPoint
		),
		TaijutsuDamage = GameConfig.BaseTaijutsuDamage
			+ stats.Taijutsu * GameConfig.TaijutsuPerPoint,
		WeaponDamage = GameConfig.BaseWeaponDamage
			+ stats.Weapon * GameConfig.WeaponPerPoint,
		NinjutsuDamage = GameConfig.BaseNinjutsuDamage
			+ stats.Ninjutsu * GameConfig.NinjutsuPerPoint,
		WalkSpeed = walkSpeed,
	}
end

-- Chakra restored per second, stepped every 10 levels.
--
-- A flat regen punishes the Chakra stat: a bigger pool with the same trickle
-- feels strictly worse than a small one. Stepping with level keeps the refill
-- time from ballooning. Note this scales with LEVEL, not with the Chakra stat,
-- so a heavy chakra build still refills proportionally slower — deliberate, so
-- investment costs something.
function Formulas.chakraRegen(level: number): number
	local steps = math.floor(level / 10)
	return GameConfig.ChakraRegenPerSecond + steps * GameConfig.ChakraRegenPer10Levels
end

-- Health an enemy of a given level spawns with.
function Formulas.enemyHealth(level: number): number
	return math.floor(GameConfig.EnemyBaseHealth + level * GameConfig.EnemyHealthPerLevel)
end

-- XP awarded for defeating an enemy of a given level, scaled by how far
-- above it the player is. Farming low-level mobs stops paying quickly.
function Formulas.xpReward(enemyLevel: number, playerLevel: number): number
	local base = 20 + enemyLevel * 8
	local gap = playerLevel - enemyLevel

	local penalty = 1
	if gap > 10 then
		penalty = math.max(0.05, 1 - (gap - 10) * 0.06)
	end

	return math.max(1, math.floor(base * penalty))
end

return Formulas
