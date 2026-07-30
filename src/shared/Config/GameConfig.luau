--!strict
-- Every tunable number in the game lives here. Balance passes should touch
-- this file and nothing else.

local Types = require(script.Parent.Parent.Types)

local GameConfig = {
	GameName = "Shinobi Legends",

	-- Bump this when Types.Profile changes shape. DataService migrates on load.
	-- v2 added ActiveQuest / QuestProgress / QuestsCompleted.
	DataVersion = 2,

	-- === Progression ===
	MaxLevel = 1000,
	StatPointsPerLevel = 3,
	MaxPointsPerStat = 2000,

	-- XP needed to go from level n to n+1.
	-- Quadratic-ish: gentle early, steep late. Level 10 ≈ 1.6k, level 100 ≈ 51k.
	XPCurve = {
		Base = 50,
		Exponent = 1.55,
	},

	-- === Base character values (before stats are spent) ===
	BaseHealth = 100,
	BaseChakra = 100,
	HealthPerLevel = 5,
	HealthPerDefensePoint = 4,
	ChakraPerChakraPoint = 3,

	-- === Damage scaling ===
	-- Damage = Base + (points spent * PerPoint)
	BaseTaijutsuDamage = 10,
	TaijutsuPerPoint = 0.8,
	BaseWeaponDamage = 12,
	WeaponPerPoint = 0.9,
	BaseNinjutsuDamage = 15,
	NinjutsuPerPoint = 1.1,

	-- === Movement ===
	BaseWalkSpeed = 16,
	WalkSpeedPerLevel = 0.01, -- +10 speed by level 1000
	MaxWalkSpeed = 40,

	-- === Chakra regen ===
	-- Regen scales every 10 levels so a deep chakra pool doesn't take forever to
	-- refill. See Formulas.chakraRegen.
	ChakraRegenPerSecond = 4,
	ChakraRegenPer10Levels = 0.6,
	ChakraRegenDelayAfterUse = 1.5,

	-- === Melee (taijutsu M1) ===
	-- Costs no chakra by design: taijutsu is the sustainable option, ninjutsu is
	-- the burst option. Scales off the Taijutsu stat.
	MeleeRange = 12,
	MeleeArcDegrees = 110,     -- frontal cone; behind you is a miss
	MeleeCooldown = 0.42,      -- per swing
	MeleeComboLength = 3,      -- swings before the combo resets
	MeleeComboResetTime = 1.2, -- idle time that drops your combo
	MeleeFinisherBonus = 1.6,  -- damage multiplier on the last hit of a combo
	MeleeMaxTargets = 3,       -- cleave cap per swing
	MeleeKnockback = 20,

	-- === Sprint (hold Shift) ===
	-- Free, unlike the dash. Sprinting is basic locomotion in this genre — gating
	-- it behind chakra would make simply crossing the village feel like a cost.
	SprintMultiplier = 1.55,
	SprintFovBoost = 6, -- small FOV push so speed reads on screen

	-- === Dash (Q) ===
	-- Costs chakra so movement competes with ninjutsu for the same resource.
	DashCost = 12,
	DashCooldown = 1.1,
	DashSpeed = 92,
	DashDuration = 0.22,
	DashUpwardBoost = 6, -- a little lift so you clear kerbs and low walls

	-- === Enemies ===
	-- Training dummies for now: they take hits and respawn, no AI yet.
	EnemyBaseHealth = 60,
	EnemyHealthPerLevel = 22,
	EnemyRespawnDelay = 6,
	EnemyDefaultLevel = 1,
	EnemyDefaultName = "Training Doll",

	-- === Quests ===
	-- Kills pay nothing on their own; XP arrives when a quest is turned in. The
	-- bonus is what makes questing worth more than aimless grinding.
	DefaultQuestKillCount = 5,
	QuestCompletionBonus = 1.2,

	-- === Animations ===
	-- Roblox asset IDs for the melee combo, one per swing, in order. Leave a slot
	-- at 0 and that swing plays nothing. Animations must be published by whoever
	-- owns this game or they silently refuse to load.
	MeleeAnimationIds = { 0, 0, 0 },
	MeleeAnimationSpeed = 1.35,
	DashAnimationId = 0,

	-- === Icons ===
	-- Uploaded kunai image for the quest compass. Leave at 0 and the compass falls
	-- back to a shape drawn from Frames, so it works either way.
	KunaiIconId = 110805418666376,
	-- The source art points down-left, so the icon needs pre-rotating for "up" to
	-- mean "straight ahead". Adjust if your upload sits at a different angle.
	KunaiIconBaseRotation = 135,

	-- === Economy ===
	StartingRyo = 0,

	-- === Persistence ===
	DataStoreName = "ShinobiProfiles_v1",
	AutosaveInterval = 60,
	SaveRetries = 4,
	SaveRetryDelay = 2,
}

-- A fresh player's save file.
function GameConfig.defaultProfile(): Types.Profile
	return {
		DataVersion = GameConfig.DataVersion,
		Level = 1,
		XP = 0,
		StatPoints = 0,
		Stats = {
			Taijutsu = 0,
			Defense = 0,
			Weapon = 0,
			Ninjutsu = 0,
			Chakra = 0,
		},
		Ryo = GameConfig.StartingRyo,
		Nature = nil,
		UnlockedJutsu = {},
		ActiveQuest = nil,
		QuestProgress = 0,
		QuestsCompleted = {},
		Playtime = 0,
		LastSeen = 0,
	}
end

return GameConfig
