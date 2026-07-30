--!strict
-- Konohagakure layout. Data only — VillageService turns this into geometry.
--
-- SCALE. 1 stud ≈ 0.34 m (a 5-stud character ≈ 1.7 m). Everything below is
-- derived from that so the village reads at human scale instead of doll-house:
--   · storey height 14 studs ≈ 4.8 m
--   · main street 44 studs ≈ 15 m across
--   · outer wall 70 studs ≈ 24 m tall, which is roughly canon
--   · walled village radius 900 studs ≈ 300 m across the middle
--
-- ORIENTATION. -Z is north. The Hokage Rock and Tower sit north, the main gate
-- south at +Z, matching the map from the series.
--
-- Districts are generated from rules with a FIXED SEED, so the village is
-- byte-identical every run and you can safely hand-edit landmarks in Studio
-- without the procedural parts shifting under you.

local Village = {}

Village.Seed = 20260729

-- How much clutter hangs off each building (0..1). Water tanks, signs, awnings,
-- shutters, pipes. This is the main performance dial — drop it to 0.5 if the
-- 1660 Super struggles, and the layout stays identical.
Village.Detail = 1.0

-- Gap left around each building when packing a district. Small on purpose: the
-- reference art has buildings almost touching, with alleys rather than lawns.
Village.BuildingGap = 5

-- === Scale ===
Village.StoreyHeight = 14
Village.GroundY = 0
Village.WallRadius = 900
Village.WallHeight = 70
Village.WallThickness = 14

-- === Palette ===
-- Warm earth tones with red, teal and slate roofs — Konoha's colour identity.
Village.Palette = {
	WallStone = Color3.fromRGB(152, 143, 126),
	WallTrim = Color3.fromRGB(120, 110, 96),
	Plaster = Color3.fromRGB(224, 208, 180),
	PlasterWarm = Color3.fromRGB(203, 178, 143),
	PlasterPale = Color3.fromRGB(236, 226, 205),
	-- Pastels straight off the reference street shots: dusty pink, sage, peach,
	-- pale blue. These are what stop the village reading as one beige mass.
	PlasterPink = Color3.fromRGB(230, 192, 186),
	PlasterSage = Color3.fromRGB(194, 208, 182),
	PlasterPeach = Color3.fromRGB(238, 212, 180),
	PlasterBlue = Color3.fromRGB(198, 212, 220),
	PlasterClay = Color3.fromRGB(212, 172, 142),
	Wood = Color3.fromRGB(112, 82, 56),
	WoodDark = Color3.fromRGB(78, 56, 38),
	RoofRed = Color3.fromRGB(154, 72, 56),
	RoofTeal = Color3.fromRGB(72, 112, 110),
	RoofSlate = Color3.fromRGB(88, 100, 124),
	RoofGreen = Color3.fromRGB(84, 116, 78),
	-- The dominant roof colour in every aerial shot is warm orange tile.
	RoofOrange = Color3.fromRGB(206, 118, 62),
	RoofTerracotta = Color3.fromRGB(184, 94, 60),
	RoofGold = Color3.fromRGB(214, 168, 74),
	RoofBlue = Color3.fromRGB(72, 104, 156),
	Road = Color3.fromRGB(168, 158, 142),
	RoadEdge = Color3.fromRGB(140, 130, 116),
	Grass = Color3.fromRGB(96, 138, 74),
	Foliage = Color3.fromRGB(74, 118, 62),
	FoliageDark = Color3.fromRGB(56, 92, 50),
	Rock = Color3.fromRGB(138, 130, 118),
	RockDark = Color3.fromRGB(112, 104, 94),
	Water = Color3.fromRGB(72, 128, 158),
	Window = Color3.fromRGB(150, 200, 230),
	HokageRed = Color3.fromRGB(178, 62, 48),
	GateGreen = Color3.fromRGB(96, 132, 88),
	Sand = Color3.fromRGB(198, 182, 148),
}

export type RoofKind = "Pitched" | "Cone" | "Flat"

export type Landmark = {
	id: string,
	kind: string,
	position: Vector3,
	rotation: number,
	width: number,
	depth: number,
	floors: number,
	roof: RoofKind,
	wallColor: Color3,
	roofColor: Color3,
	sign: string?,
	signColor: Color3?,
}

-- === Landmarks ===
-- Hand-placed, recognisable, and the things a player orients by.
local P = Village.Palette

local Landmarks: { Landmark } = {
	{
		-- Built by Structures.hokageTower, not the generic path — the red drum, the
		-- cream band with the 火 crest, the gold skirt and the spiked blue cap all
		-- need placing exactly.
		id = "HokageTower",
		kind = "HokageTower",
		position = Vector3.new(0, 0, -430),
		rotation = 0,
		width = 132,
		depth = 132,
		floors = 5,
		roof = "Cone",
		wallColor = P.PlasterPale,
		roofColor = P.HokageRed,
		sign = "火",
		signColor = Color3.fromRGB(245, 230, 215),
	},
	{
		-- The thin blue-cone tower on every skyline shot.
		id = "BlueSpire",
		kind = "Spire",
		position = Vector3.new(-215, 0, -330),
		rotation = 0,
		width = 46,
		depth = 46,
		floors = 10,
		roof = "Cone",
		wallColor = P.PlasterPale,
		roofColor = P.RoofBlue,
	},
	{
		id = "TempleEast",
		kind = "Pagoda",
		position = Vector3.new(560, 0, -560),
		rotation = 0,
		width = 110,
		depth = 96,
		floors = 4,
		roof = "Pitched",
		wallColor = P.Plaster,
		roofColor = P.RoofOrange,
	},
	{
		id = "Hospital",
		kind = "Hall",
		position = Vector3.new(370, 0, -110),
		rotation = 0,
		width = 170,
		depth = 130,
		floors = 4,
		roof = "Flat",
		wallColor = P.PlasterPale,
		roofColor = P.RoofTeal,
		sign = "Hospital",
		signColor = Color3.fromRGB(200, 235, 245),
	},
	{
		id = "IchirakuRamen",
		kind = "Stall",
		position = Vector3.new(-118, 0, 236),
		rotation = 180,
		width = 46,
		depth = 30,
		floors = 1,
		roof = "Pitched",
		wallColor = P.Wood,
		roofColor = P.RoofRed,
		sign = "一楽",
		signColor = Color3.fromRGB(250, 240, 220),
	},
	{
		id = "UchihaCompound",
		kind = "Compound",
		position = Vector3.new(470, 0, 430),
		rotation = -20,
		width = 260,
		depth = 200,
		floors = 2,
		roof = "Pitched",
		wallColor = P.PlasterWarm,
		roofColor = P.RoofSlate,
		sign = "うちは",
		signColor = Color3.fromRGB(230, 120, 110),
	},
	{
		id = "HyugaCompound",
		kind = "Compound",
		position = Vector3.new(-500, 0, -330),
		rotation = 25,
		width = 250,
		depth = 195,
		floors = 2,
		roof = "Pitched",
		wallColor = P.Plaster,
		roofColor = P.RoofGreen,
		sign = "日向",
		signColor = Color3.fromRGB(210, 220, 240),
	},
	{
		id = "ShinobiHQ",
		kind = "Hall",
		position = Vector3.new(150, 0, -250),
		rotation = 0,
		width = 130,
		depth = 100,
		floors = 3,
		roof = "Pitched",
		wallColor = P.PlasterWarm,
		roofColor = P.RoofSlate,
	},
	{
		id = "Bathhouse",
		kind = "Hall",
		position = Vector3.new(-210, 0, 430),
		rotation = 0,
		width = 110,
		depth = 90,
		floors = 2,
		roof = "Pitched",
		wallColor = P.Plaster,
		roofColor = P.RoofTeal,
		sign = "湯",
		signColor = Color3.fromRGB(240, 235, 220),
	},
}

Village.Landmarks = Landmarks

-- === Ninja Academy ===
-- Not in Landmarks: the Academy owns a whole precinct, not just a footprint —
-- the building, a packed-sand forecourt with the swing tree, and a fenced
-- courtyard out the back. VillageService.buildAcademy lays out all three from
-- this one block, the way HokageRock gets its own builder.
--
-- ORIENTATION. rotation 90 turns the front doors east, so they open onto the
-- north–south street at x = -300. "Behind" is therefore world -X: the courtyard
-- sits west of the building, tucked between it and the outer wall, which is the
-- only stretch of the west side with nothing already claimed on it.
-- Derived values are computed as locals first and folded into the table literal.
-- A strict-mode table is sealed once written, so `Village.Academy.base = ...`
-- after the fact would not compile.
local academyPosition = Vector3.new(-430, 0, -70)
local academyRotation = 90
local academyDepth = 120
local courtyardWidth = 200
local courtyardDepth = 190
local courtyardGap = 26

local academyBase = CFrame.new(academyPosition) * CFrame.Angles(0, math.rad(academyRotation), 0)

-- The courtyard centre has to agree with the building's position and rotation,
-- or the enemy spawns drift off the sand and into the fence.
local courtyardCenter = (
	academyBase * CFrame.new(0, 0, -(academyDepth / 2 + courtyardGap + courtyardDepth / 2))
).Position

Village.Academy = {
	position = academyPosition,
	rotation = academyRotation,
	base = academyBase,
	width = 150,
	depth = academyDepth,
	-- Roof cones stacked on the central drum.
	tiers = 3,
	wallColor = P.PlasterPale,
	roofColor = P.RoofTerracotta,
	-- Packed-sand apron out front. The swing tree stands at its north edge.
	forecourtDepth = 62,
	-- The fenced courtyard. This is the tutorial zone — Ibiki and the training
	-- dolls live in here, so it's sized to fight in rather than to look at.
	courtyardWidth = courtyardWidth,
	courtyardDepth = courtyardDepth,
	courtyardGap = courtyardGap,
	courtyardCenter = courtyardCenter,
	-- Largest circle that fits inside the fence with room to stand at the edge.
	courtyardRadius = math.min(courtyardWidth, courtyardDepth) / 2 - 13,
	fenceHeight = 16,
	-- Gap left in the fence on the building's centre line, facing the back door.
	gateWidth = 34,
}

-- === Districts ===
-- Rule-driven: a bounded area, a building count, size ranges and a palette.
-- VillageService lays them out on a jittered grid and skips anything overlapping
-- a landmark or a road.

export type District = {
	id: string,
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	count: number,
	widthRange: NumberRange,
	depthRange: NumberRange,
	floorRange: NumberRange,
	roof: RoofKind,
	roundChance: number,
	wallColors: { Color3 },
	roofColors: { Color3 },
}

-- Footprints are deliberately small and counts high. The reference village is
-- packed shoulder-to-shoulder — narrow shophouses on tight plots, not detached
-- houses with space around them.
local Districts: { District } = {
	{
		id = "MarketSouth",
		bounds = { minX = -290, maxX = 290, minZ = 70, maxZ = 400 },
		count = 62,
		widthRange = NumberRange.new(22, 38),
		depthRange = NumberRange.new(22, 34),
		floorRange = NumberRange.new(2, 4),
		roof = "Pitched",
		roundChance = 0.08,
		wallColors = { P.PlasterPink, P.PlasterSage, P.PlasterPeach, P.Plaster, P.PlasterClay },
		roofColors = { P.RoofOrange, P.RoofTerracotta, P.RoofTeal, P.RoofSlate },
	},
	{
		id = "CentralCore",
		bounds = { minX = -290, maxX = 290, minZ = -200, maxZ = 40 },
		count = 46,
		widthRange = NumberRange.new(24, 42),
		depthRange = NumberRange.new(24, 38),
		floorRange = NumberRange.new(2, 5),
		roof = "Pitched",
		roundChance = 0.3,
		wallColors = { P.PlasterPale, P.PlasterPink, P.PlasterBlue, P.Plaster },
		roofColors = { P.RoofOrange, P.RoofRed, P.RoofTeal, P.RoofSlate },
	},
	{
		id = "HousingWest",
		bounds = { minX = -810, maxX = -320, minZ = 60, maxZ = 620 },
		count = 74,
		widthRange = NumberRange.new(26, 46),
		depthRange = NumberRange.new(24, 40),
		floorRange = NumberRange.new(2, 5),
		roof = "Flat",
		roundChance = 0.45,
		wallColors = { P.PlasterPale, P.Plaster, P.PlasterSage, P.PlasterBlue },
		roofColors = { P.RoofTeal, P.RoofSlate, P.RoofOrange, P.RoofGreen },
	},
	{
		id = "HousingEast",
		bounds = { minX = 320, maxX = 810, minZ = 60, maxZ = 600 },
		count = 72,
		widthRange = NumberRange.new(26, 46),
		depthRange = NumberRange.new(24, 40),
		floorRange = NumberRange.new(2, 5),
		roof = "Flat",
		roundChance = 0.42,
		wallColors = { P.PlasterPale, P.PlasterPeach, P.PlasterClay, P.Plaster },
		roofColors = { P.RoofOrange, P.RoofTerracotta, P.RoofSlate, P.RoofTeal },
	},
	{
		id = "HousingNorth",
		bounds = { minX = -330, maxX = 330, minZ = -680, maxZ = -500 },
		count = 40,
		widthRange = NumberRange.new(28, 50),
		depthRange = NumberRange.new(26, 42),
		floorRange = NumberRange.new(3, 6),
		roof = "Flat",
		roundChance = 0.55,
		wallColors = { P.PlasterPale, P.Plaster, P.PlasterBlue },
		roofColors = { P.RoofTeal, P.RoofOrange, P.RoofRed },
	},
	{
		id = "OldQuarterNE",
		bounds = { minX = 230, maxX = 700, minZ = -440, maxZ = -140 },
		count = 52,
		widthRange = NumberRange.new(22, 36),
		depthRange = NumberRange.new(20, 32),
		floorRange = NumberRange.new(1, 3),
		roof = "Pitched",
		roundChance = 0.05,
		wallColors = { P.PlasterWarm, P.PlasterClay, P.Wood, P.PlasterPeach },
		roofColors = { P.RoofSlate, P.RoofGreen, P.RoofTerracotta, P.RoofOrange },
	},
	{
		id = "OldQuarterSW",
		bounds = { minX = -720, maxX = -330, minZ = -440, maxZ = -40 },
		count = 48,
		widthRange = NumberRange.new(22, 36),
		depthRange = NumberRange.new(20, 32),
		floorRange = NumberRange.new(1, 3),
		roof = "Pitched",
		roundChance = 0.05,
		wallColors = { P.PlasterWarm, P.Plaster, P.PlasterSage },
		roofColors = { P.RoofRed, P.RoofSlate, P.RoofOrange },
	},
	{
		id = "SouthGateRow",
		bounds = { minX = -260, maxX = 260, minZ = 480, maxZ = 720 },
		count = 44,
		widthRange = NumberRange.new(22, 36),
		depthRange = NumberRange.new(20, 32),
		floorRange = NumberRange.new(1, 3),
		roof = "Pitched",
		roundChance = 0.06,
		wallColors = { P.Plaster, P.PlasterPeach, P.PlasterPink },
		roofColors = { P.RoofOrange, P.RoofTerracotta, P.RoofGreen, P.RoofTeal },
	},
}

Village.Districts = Districts

-- === Roads ===
-- Axis-aligned strips. The main street runs north from the gate to the tower.
export type Road = {
	from: Vector3,
	to: Vector3,
	width: number,
}

-- Narrow on purpose. The reference streets are canyons — two storeys of shopfront
-- either side of a path barely wide enough for a cart. The old 46-stud avenue read
-- as a boulevard, which is why the village felt empty.
--   main street 22 studs ≈ 7.5 m
--   side street 15 studs ≈ 5 m
--   alley       10 studs ≈ 3.4 m
local Roads: { Road } = {
	-- Main street: south gate up to the Hokage Tower plaza.
	{ from = Vector3.new(0, 0, 880), to = Vector3.new(0, 0, -360), width = 22 },

	-- Cross streets.
	{ from = Vector3.new(-840, 0, 40), to = Vector3.new(840, 0, 40), width = 16 },
	{ from = Vector3.new(-840, 0, 300), to = Vector3.new(840, 0, 300), width = 15 },
	{ from = Vector3.new(-820, 0, 520), to = Vector3.new(820, 0, 520), width = 15 },
	{ from = Vector3.new(-620, 0, -220), to = Vector3.new(620, 0, -220), width = 15 },
	{ from = Vector3.new(-600, 0, -480), to = Vector3.new(600, 0, -480), width = 15 },

	-- North–south streets.
	{ from = Vector3.new(-300, 0, 760), to = Vector3.new(-300, 0, -460), width = 15 },
	{ from = Vector3.new(300, 0, 760), to = Vector3.new(300, 0, -460), width = 15 },
	-- Stops at the z=40 cross street instead of running on to -300: north of that
	-- it would have driven straight through the Academy courtyard.
	{ from = Vector3.new(-600, 0, 640), to = Vector3.new(-600, 0, 40), width = 14 },
	{ from = Vector3.new(600, 0, 640), to = Vector3.new(600, 0, -300), width = 14 },

	-- Alleys, so blocks aren't solid slabs.
	{ from = Vector3.new(-150, 0, 700), to = Vector3.new(-150, 0, 60), width = 10 },
	{ from = Vector3.new(150, 0, 700), to = Vector3.new(150, 0, 60), width = 10 },
	{ from = Vector3.new(-450, 0, 600), to = Vector3.new(-450, 0, 60), width = 10 },
	{ from = Vector3.new(450, 0, 600), to = Vector3.new(450, 0, 60), width = 10 },
	{ from = Vector3.new(-740, 0, 420), to = Vector3.new(740, 0, 420), width = 10 },
	-- Starts at the x=-300 street: it used to run west through the Academy.
	{ from = Vector3.new(-300, 0, -100), to = Vector3.new(520, 0, -100), width = 10 },
}

Village.Roads = Roads

-- === Gates ===
-- Angle in degrees around the wall; 0 is +Z (south), matching the canon main gate.
Village.Gates = {
	{ id = "SouthMain", angle = 0, width = 90, sign = "木ノ葉" },
	{ id = "WestGate", angle = 90, width = 62, sign = nil },
	{ id = "NorthGate", angle = 180, width = 62, sign = nil },
	{ id = "EastGate", angle = 270, width = 62, sign = nil },
}

-- === Outer zones ===
-- Everything beyond the wall. Each one is a quest area, so enemies and the
-- geography agree with each other.
export type Zone = {
	id: string,
	displayName: string,
	center: Vector3,
	radius: number,
	kind: string,
	groundColor: Color3,
	treeCount: number,
}

local Zones: { Zone } = {
	{
		-- The starting zone, and the only one inside the wall. Geometry is built by
		-- buildAcademy, not buildZones — kind "Courtyard" makes buildZones skip it,
		-- so it appears here purely so quests, the compass and the enemy spawner
		-- can all find it by id like any other area.
		id = "AcademyCourtyard",
		displayName = "Academy Courtyard",
		center = Village.Academy.courtyardCenter,
		radius = Village.Academy.courtyardRadius,
		kind = "Courtyard",
		groundColor = P.Sand,
		treeCount = 0,
	},
	{
		id = "LeafOutskirts",
		displayName = "Leaf Outskirts",
		center = Vector3.new(0, 0, 1180),
		radius = 260,
		kind = "Field",
		groundColor = P.Grass,
		treeCount = 26,
	},
	{
		id = "TrainingGrounds",
		displayName = "Training Grounds",
		center = Vector3.new(-1240, 0, 300),
		radius = 240,
		kind = "Training",
		groundColor = Color3.fromRGB(122, 148, 92),
		treeCount = 22,
	},
	{
		id = "ForestOfDeath",
		displayName = "Forest of Death",
		center = Vector3.new(1520, 0, 220),
		radius = 340,
		kind = "Forest",
		groundColor = Color3.fromRGB(58, 84, 52),
		treeCount = 90,
	},
	{
		id = "AkatsukiOutpost",
		displayName = "Akatsuki Outpost",
		center = Vector3.new(180, 0, -1620),
		radius = 240,
		kind = "Ruins",
		groundColor = Color3.fromRGB(104, 96, 88),
		treeCount = 14,
	},
}

Village.Zones = Zones

-- === Hokage Rock ===
-- The cliff north of the village with the faces carved into it.
Village.HokageRock = {
	center = Vector3.new(0, 0, -1000),
	width = 1500,
	height = 340,
	depth = 260,
	faceCount = 5,
}

-- === Plaza ===
-- The village square on the main street, north of the gate row. Still where the
-- higher-tier quest givers stand; it just isn't the spawn any more.
Village.PlazaPosition = Vector3.new(0, 0, 260)

-- === Spawn ===
-- The Academy forecourt. New players land facing the school with the swing tree
-- beside them, and the tutorial courtyard is a walk around the building.
Village.SpawnPosition = (
	Village.Academy.base
	* CFrame.new(0, 6, Village.Academy.depth / 2 + Village.Academy.forecourtDepth * 0.55)
).Position

return Village
