--!strict
-- Which enemies populate which outer zone. Zone ids match Village.Zones, so the
-- geography and the spawns can't drift apart — and they match the quest
-- TargetName in Quests.luau, which is what makes each quest completable.
--
-- Change a count here rather than touching EnemyService.

-- Kind drives appearance only, never stats:
--   "Doll"  — a straw training dummy on a post. Tutorial targets.
--   "Nin"   — a humanoid figure.
export type Area = {
	ZoneId: string,
	EnemyName: string,
	Level: number,
	Count: number,
	Kind: string,
}

local EnemyAreas: { Area } = {
	-- The tutorial population, in the Academy courtyard rather than out in the
	-- fields — it's a school training yard, and it's the first thing a new player
	-- walks into. Count is lower than the outer zones because the yard is small.
	{ ZoneId = "AcademyCourtyard", EnemyName = "Training Doll", Level = 1, Count = 10, Kind = "Doll" },
	{ ZoneId = "TrainingGrounds", EnemyName = "Rogue Genin", Level = 10, Count = 12, Kind = "Nin" },
	{ ZoneId = "ForestOfDeath", EnemyName = "Missing-Nin", Level = 25, Count = 14, Kind = "Nin" },
	{ ZoneId = "AkatsukiOutpost", EnemyName = "Akatsuki Scout", Level = 50, Count = 5, Kind = "Nin" },
}

return EnemyAreas
