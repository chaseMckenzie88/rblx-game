--!strict
-- Shared type definitions. Every module references these so a change to the
-- save format shows up as a type error everywhere it matters, not at runtime.

export type StatName = "Taijutsu" | "Defense" | "Weapon" | "Ninjutsu" | "Chakra"

export type Stats = {
	Taijutsu: number,
	Defense: number,
	Weapon: number,
	Ninjutsu: number,
	Chakra: number,
}

-- Everything persisted for a player. Bump DataVersion in GameConfig when this
-- shape changes so old saves get migrated instead of silently misread.
export type Profile = {
	DataVersion: number,
	Level: number,
	XP: number,
	StatPoints: number,
	Stats: Stats,
	Ryo: number,
	Nature: string?,
	UnlockedJutsu: { string },
	-- Quests. XP comes from turning these in, never from individual kills.
	ActiveQuest: string?,
	QuestProgress: number,
	QuestsCompleted: { [string]: number },
	Playtime: number,
	LastSeen: number,
}

-- Values computed from level + stats. Never saved: always derived, so
-- rebalancing the formulas retroactively fixes every existing player.
export type Derived = {
	MaxHealth: number,
	MaxChakra: number,
	TaijutsuDamage: number,
	WeaponDamage: number,
	NinjutsuDamage: number,
	WalkSpeed: number,
}

export type Rank = {
	Name: string,
	MinLevel: number,
	Color: Color3,
}

export type Nature = {
	Id: string,
	Name: string,
	Kanji: string,
	Rarity: "Common" | "Uncommon" | "Rare" | "Legendary" | "Mythic",
	Color: Color3,
	StrongAgainst: string?,
	WeakAgainst: string?,
}

-- One area's kill quest. XPReward is usually nil, meaning "work it out from the
-- target's level and the kill count at turn-in time" — that keeps the anti-farm
-- penalty in Formulas.xpReward alive. Special areas override it explicitly.
export type Quest = {
	Id: string,
	Name: string,
	AreaName: string,
	-- Village.Zones id this quest sends you to. Explicit rather than reusing Id,
	-- because they don't always match (AkatsukiScout → AkatsukiOutpost) and the
	-- quest compass needs real world coordinates.
	ZoneId: string,
	TargetName: string,
	TargetLevel: number,
	KillCount: number,
	RequiredLevel: number,
	XPReward: number?,
	RyoReward: number,
	Repeatable: boolean,
}

export type Jutsu = {
	Id: string,
	Name: string,
	Nature: string?,
	RequiredLevel: number,
	ChakraCost: number,
	Cooldown: number,
	BaseDamage: number,
	Scaling: StatName,
	Description: string,
}

return nil
