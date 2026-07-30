--!strict
-- Building archetypes. Each one composes Builder primitives plus Details clutter,
-- and every call takes an rng so no two buildings come out identical.
--
-- Archetypes, matched to the reference art:
--   Shophouse  — narrow, tall, street-facing. Awning + hanging kanji sign +
--                shutters. This is the bulk of the village.
--   RoundTower — cylindrical drum with a dome or cone. Konoha's signature.
--   Pagoda     — stacked tiers with wide eaves. Academy, temples.
--   HokageTower— the red drum with the 火 crest, built exactly.
--   Spire      — the tall blue conical roof tower from the skyline.

local Builder = require(script.Parent.Builder)
local Details = require(script.Parent.Details)

local Structures = {}

export type Spec = {
	position: Vector3,
	rotation: number,
	width: number,
	depth: number,
	floors: number,
	storey: number,
	wallColor: Color3,
	roofColor: Color3,
	trimColor: Color3,
	windowColor: Color3,
	-- Street side gets the shopfront dressing; 1 = +Z face.
	frontFacing: boolean,
	detail: number, -- 0..1, how much clutter to hang on it
}

local function baseCFrame(spec: Spec): CFrame
	return CFrame.new(Vector3.new(spec.position.X, 0, spec.position.Z))
		* CFrame.Angles(0, math.rad(spec.rotation), 0)
end

-- Rows of small square windows. The reference facades are mostly small punched
-- openings, not big glass.
local function punchedWindows(
	parent: Instance,
	base: CFrame,
	spec: Spec,
	height: number,
	rng: Random
)
	local perFloor = math.max(2, math.floor(spec.width / 13))

	for floor = 0, spec.floors - 1 do
		local y = floor * spec.storey + spec.storey * 0.58
		local spacing = spec.width * 0.82 / perFloor

		for i = 0, perFloor - 1 do
			local x = -spec.width * 0.41 + spacing * (i + 0.5)
			local w = math.min(6.5, spacing * 0.55)

			for _, sz in { 1, -1 } do
				local at = base * CFrame.new(x, y, sz * (spec.depth / 2 + 0.3))
				Builder.block(
					parent,
					"Window",
					at,
					Vector3.new(w, 6.4, 0.6),
					spec.windowColor,
					{ material = Enum.Material.Glass, reflectance = 0.12, collide = false }
				)
				-- Frame surround.
				Builder.block(
					parent,
					"WindowFrame",
					at * CFrame.new(0, 0, -0.2),
					Vector3.new(w + 1.6, 8, 0.5),
					spec.trimColor,
					{ material = Enum.Material.Wood, collide = false }
				)

				-- Shutters on some upper windows only — every window having them
				-- looks mechanical.
				if floor > 0 and rng:NextNumber() < 0.34 * spec.detail then
					Details.shutters(parent, at, w, 7)
				end
			end
		end
	end
end

-- Rooftop clutter. Tanks, vents, antennae, chimney — placed on a small grid so
-- they don't intersect each other.
local function rooftop(parent: Instance, base: CFrame, spec: Spec, roofY: number, rng: Random)
	local slots: { Vector3 } = {}
	local cols = math.max(1, math.floor(spec.width / 22))
	local rows = math.max(1, math.floor(spec.depth / 22))

	for cx = 0, cols - 1 do
		for cz = 0, rows - 1 do
			local x = -spec.width / 2 + (cx + 0.5) * (spec.width / cols)
			local z = -spec.depth / 2 + (cz + 0.5) * (spec.depth / rows)
			table.insert(slots, Vector3.new(x, roofY, z))
		end
	end

	-- Shuffle so which slot gets what varies per building.
	for i = #slots, 2, -1 do
		local j = rng:NextInteger(1, i)
		slots[i], slots[j] = slots[j], slots[i]
	end

	local budget = math.max(1, math.floor(#slots * (0.45 + spec.detail * 0.45)))

	for i = 1, math.min(budget, #slots) do
		local at = base * CFrame.new(slots[i].X, roofY, slots[i].Z)
		local roll = rng:NextNumber()

		if roll < 0.5 then
			Details.waterTank(parent, at, rng:NextNumber(0.85, 1.25))
		elseif roll < 0.72 then
			Details.roofVent(parent, at, rng:NextNumber(0.9, 1.2))
		elseif roll < 0.86 then
			Details.antenna(parent, at, rng:NextInteger(16, 30))
		else
			Details.chimney(parent, at, rng:NextInteger(9, 16))
		end
	end
end

-- ============================================================ shophouse

function Structures.shophouse(parent: Instance, spec: Spec, rng: Random): Model
	local model = Builder.group("Shophouse", parent)
	local base = baseCFrame(spec)
	local height = spec.floors * spec.storey

	local body = Builder.block(
		model,
		"Body",
		base * CFrame.new(0, height / 2, 0),
		Vector3.new(spec.width, height, spec.depth),
		spec.wallColor,
		{ material = Enum.Material.Plaster }
	)

	-- Ground floor is a slightly darker plinth — nearly every reference facade
	-- has this two-tone split.
	Builder.block(
		model,
		"Plinth",
		base * CFrame.new(0, spec.storey * 0.5, 0),
		Vector3.new(spec.width + 1.2, spec.storey, spec.depth + 1.2),
		spec.trimColor,
		{ material = Enum.Material.WoodPlanks }
	)

	punchedWindows(model, base, spec, height, rng)

	-- Shopfront: doorway, awning, hanging sign.
	local frontZ = spec.depth / 2
	Builder.block(
		model,
		"Door",
		base * CFrame.new(0, spec.storey * 0.36, frontZ + 0.4),
		Vector3.new(math.min(12, spec.width * 0.32), spec.storey * 0.68, 1),
		Details.Colors.WoodDark,
		{ material = Enum.Material.WoodPlanks, collide = false }
	)

	if rng:NextNumber() < 0.75 * spec.detail then
		Details.awning(
			model,
			base * CFrame.new(0, spec.storey * 0.92, frontZ + 5),
			spec.width * 0.86,
			spec.roofColor
		)
	end

	if rng:NextNumber() < 0.6 * spec.detail then
		local kanji = Details.ShopKanji[rng:NextInteger(1, #Details.ShopKanji)]
		Details.hangingSign(
			model,
			base * CFrame.new(spec.width * 0.34, spec.storey * 1.9, frontZ + 3),
			kanji
		)
	end

	if spec.floors >= 3 and rng:NextNumber() < 0.4 * spec.detail then
		Details.balcony(
			model,
			base * CFrame.new(0, spec.storey * 2 + 1, frontZ + 4),
			spec.width * 0.7
		)
	end

	if rng:NextNumber() < 0.55 * spec.detail then
		Details.drainpipe(
			model,
			base * CFrame.new(spec.width / 2 - 1, 0, frontZ + 1),
			height
		)
	end

	if rng:NextNumber() < 0.3 * spec.detail then
		Details.acUnit(model, base * CFrame.new(-spec.width * 0.3, spec.storey * 1.6, frontZ + 2))
	end

	-- Roof: pitched with hooked ridge ends, or flat and walkable.
	local pitched = rng:NextNumber() < 0.55
	if pitched then
		Builder.eaves(model, base * CFrame.new(0, height + 0.5, 0), spec.width, spec.depth, spec.roofColor)
		Builder.pitchedRoof(
			model,
			base * CFrame.new(0, height + 1.2, 0),
			spec.width + 4,
			spec.depth + 4,
			math.max(8, spec.width * 0.26),
			spec.roofColor
		)
		Builder.ridgeHooks(model, base, spec.width + 4, spec.depth + 4, height + 2, spec.roofColor)
		rooftop(model, base, spec, height + math.max(8, spec.width * 0.26) + 1, rng)
	else
		Builder.block(
			model,
			"RoofSlab",
			base * CFrame.new(0, height + 1, 0),
			Vector3.new(spec.width + 3, 2, spec.depth + 3),
			spec.roofColor,
			{ material = Enum.Material.Concrete }
		)
		for _, s in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			Builder.block(
				model,
				"Parapet",
				base * CFrame.new(s[1] * spec.width / 2, height + 3.5, s[2] * spec.depth / 2),
				if s[1] ~= 0
					then Vector3.new(2, 3.4, spec.depth + 3)
					else Vector3.new(spec.width + 3, 3.4, 2),
				spec.trimColor,
				{ material = Enum.Material.Concrete }
			)
		end
		rooftop(model, base, spec, height + 2, rng)
	end

	Builder.anchorModel(model, body)
	return model
end

-- ============================================================ round tower

function Structures.roundTower(parent: Instance, spec: Spec, rng: Random): Model
	local model = Builder.group("RoundTower", parent)
	local base = baseCFrame(spec)
	local height = spec.floors * spec.storey

	local body = Builder.cylinder(
		model,
		"Body",
		base * CFrame.new(0, height / 2, 0),
		spec.width,
		height,
		spec.wallColor,
		{ material = Enum.Material.Plaster }
	)

	-- Storey banding rings — how the reference round buildings read as multi-floor.
	for floor = 1, spec.floors - 1 do
		Builder.cylinder(
			model,
			"Band",
			base * CFrame.new(0, floor * spec.storey, 0),
			spec.width + 2.4,
			2.2,
			spec.trimColor,
			{ material = Enum.Material.Concrete }
		)
	end

	-- Windows set around the drum.
	local perRing = math.max(5, math.floor(spec.width / 9))
	for floor = 0, spec.floors - 1 do
		for i = 0, perRing - 1 do
			local theta = (i / perRing) * math.pi * 2
			local at = base
				* CFrame.Angles(0, theta, 0)
				* CFrame.new(0, floor * spec.storey + spec.storey * 0.58, spec.width / 2)
			Builder.block(
				model,
				"Window",
				at,
				Vector3.new(5.4, 6, 0.7),
				spec.windowColor,
				{ material = Enum.Material.Glass, reflectance = 0.12, collide = false }
			)
		end
	end

	-- Wide overhanging eave skirt, then dome or cone.
	Builder.cylinder(
		model,
		"Eave",
		base * CFrame.new(0, height + 1, 0),
		spec.width + 14,
		2.6,
		spec.roofColor,
		{ material = Enum.Material.Slate }
	)

	if rng:NextNumber() < 0.5 then
		Builder.coneRoof(
			model,
			base * CFrame.new(0, height + 2, 0),
			spec.width + 8,
			spec.width * 0.5,
			spec.roofColor,
			5
		)
	else
		-- Shallow dome from stacked discs.
		for i = 0, 3 do
			local t = i / 4
			Builder.cylinder(
				model,
				`Dome{i}`,
				base * CFrame.new(0, height + 2 + i * 3.2, 0),
				(spec.width + 6) * (1 - t * t * 0.85),
				3.4,
				spec.roofColor,
				{ material = Enum.Material.Slate }
			)
		end
		rooftop(model, base, spec, height + 2, rng)
	end

	Builder.anchorModel(model, body)
	return model
end

-- ============================================================ pagoda

function Structures.pagoda(parent: Instance, spec: Spec, tiers: number, crest: boolean): Model
	local model = Builder.group("Pagoda", parent)
	local base = baseCFrame(spec)

	-- Stone platform.
	local body = Builder.block(
		model,
		"Platform",
		base * CFrame.new(0, 2, 0),
		Vector3.new(spec.width + 18, 4, spec.depth + 18),
		spec.trimColor,
		{ material = Enum.Material.Slate }
	)

	Builder.tieredRoof(
		model,
		base * CFrame.new(0, 4, 0),
		spec.width,
		spec.depth,
		tiers,
		spec.storey * 1.15,
		spec.roofColor,
		spec.wallColor
	)

	-- Entrance: red double doors under a small porch.
	local frontZ = spec.depth / 2 + 4
	Builder.block(
		model,
		"Doors",
		base * CFrame.new(0, 11, frontZ),
		Vector3.new(18, 14, 1.4),
		Color3.fromRGB(168, 58, 48),
		{ material = Enum.Material.WoodPlanks }
	)
	Builder.block(
		model,
		"Porch",
		base * CFrame.new(0, 20, frontZ + 2),
		Vector3.new(30, 1.6, 10),
		spec.roofColor,
		{ material = Enum.Material.Slate }
	)

	if crest then
		-- Details.crest applies its own facing rotation, so pass a plain frame.
		Details.crest(model, base * CFrame.new(0, 30, frontZ + 1.6), 22, Color3.fromRGB(96, 150, 96))
	end

	-- Finial spike on top.
	local topY = 4 + tiers * spec.storey * 1.15
	Builder.tube(model, "Finial", base * CFrame.new(0, topY + 8, 0), 2.2, 16, Color3.fromRGB(198, 168, 96), {
		material = Enum.Material.Metal,
	})
	Builder.sphere(
		model,
		"FinialBall",
		(base * CFrame.new(0, topY + 17, 0)).Position,
		5,
		Color3.fromRGB(212, 180, 104),
		{ material = Enum.Material.Metal }
	)

	Builder.anchorModel(model, body)
	return model
end

-- ============================================================ Ninja Academy

-- Built to the reference art rather than through the generic pagoda path. The
-- silhouette that makes it recognisable is a cream drum pushed forward of the
-- mass, carrying three stacked shingle cones under a gold finial, with lower
-- tiered wings either side. Red doors sit under the drum's flared base eave,
-- and the circular 忍 crest hangs above them on its 忍者アカデミー banner.
--
-- Front is local +Z, as everywhere else in this file. Village.Academy.rotation
-- is what points it at the street.
function Structures.academy(parent: Instance, spec: Spec, tiers: number): Model
	local model = Builder.group("Academy", parent)
	local base = baseCFrame(spec)

	local RED = Color3.fromRGB(178, 64, 50)
	local RED_DEEP = Color3.fromRGB(146, 44, 36)
	local TRIM = Color3.fromRGB(232, 222, 200)
	local WINDOW = Color3.fromRGB(126, 178, 208)
	local GOLD = Color3.fromRGB(214, 176, 96)
	local GREY = Color3.fromRGB(156, 158, 156)

	local platformH = 4
	local drumDiameter = 64
	local drumHeight = 74
	-- Pushed forward so the tower reads as a separate round mass rather than a
	-- bump on a wall — that projection is the whole shape of the building.
	local drumZ = spec.depth / 2 - 38
	local drumTop = platformH + drumHeight

	-- Stone platform the whole precinct sits on.
	local platform = Builder.block(
		model,
		"Platform",
		base * CFrame.new(0, platformH / 2, 0),
		Vector3.new(spec.width + 18, platformH, spec.depth + 18),
		spec.trimColor,
		{ material = Enum.Material.Slate, castShadow = true }
	)

	-- ---- rear mass and side wings -------------------------------------------
	-- tieredRoof draws its own wall band per tier, so these need no separate body.
	Builder.tieredRoof(
		model,
		base * CFrame.new(0, platformH, -spec.depth / 2 + 22),
		spec.width,
		46,
		3,
		15,
		spec.roofColor,
		spec.wallColor
	)

	for _, sx in { -1, 1 } do
		Builder.tieredRoof(
			model,
			base * CFrame.new(sx * (spec.width / 2 - 21), platformH, spec.depth / 2 - 46),
			42,
			spec.depth * 0.62,
			2,
			16,
			spec.roofColor,
			spec.wallColor
		)

		-- Punched windows down the wing's outer face.
		for floor = 0, 1 do
			for i = -1, 1 do
				local at = base
					* CFrame.new(
						sx * (spec.width / 2 - 0.6),
						platformH + 6 + floor * 16,
						spec.depth / 2 - 46 + i * 20
					)
					* CFrame.Angles(0, math.rad(sx * 90), 0)
				Builder.block(model, "Window", at, Vector3.new(6, 7, 0.8), WINDOW, {
					material = Enum.Material.Glass,
					reflectance = 0.12,
					collide = false,
				})
				Builder.block(model, "WindowFrame", at * CFrame.new(0, 0, -0.3), Vector3.new(8, 9, 0.6), RED, {
					material = Enum.Material.Wood,
					collide = false,
				})
			end
		end
	end

	-- ---- the drum ------------------------------------------------------------
	Builder.cylinder(
		model,
		"Drum",
		base * CFrame.new(0, platformH + drumHeight / 2, drumZ),
		drumDiameter,
		drumHeight,
		spec.wallColor,
		{ material = Enum.Material.Plaster, castShadow = true }
	)

	-- Red panelled ground storey, wrapping the drum below the entrance eave.
	Builder.cylinder(
		model,
		"BaseBand",
		base * CFrame.new(0, platformH + 11, drumZ),
		drumDiameter + 2.4,
		22,
		RED,
		{ material = Enum.Material.Plaster }
	)

	-- Flared shingle skirts. Each storey on the reference ends in one of these
	-- rather than a flat band, and they're what make the drum read as tiered.
	local skirts = { { 24, 30 }, { 44, 24 }, { 62, 20 } }
	for index, skirt in skirts do
		local y, overhang = skirt[1] :: number, skirt[2] :: number
		Builder.cylinder(
			model,
			`Skirt{index}`,
			base * CFrame.new(0, platformH + y, drumZ),
			drumDiameter + overhang,
			3,
			spec.roofColor,
			{ material = Enum.Material.Slate, castShadow = index == 1 }
		)
		Builder.cylinder(
			model,
			`SkirtLip{index}`,
			base * CFrame.new(0, platformH + y - 2.4, drumZ),
			drumDiameter + overhang - 7,
			2.4,
			spec.roofColor,
			{ material = Enum.Material.Slate, collide = false }
		)
	end

	-- Windows set around the drum, between the skirts.
	for _, ringY in { 34, 52 } do
		for i = 0, 9 do
			local theta = (i / 10) * math.pi * 2
			local at = base
				* CFrame.new(0, 0, drumZ)
				* CFrame.Angles(0, theta, 0)
				* CFrame.new(0, platformH + ringY, drumDiameter / 2)
			Builder.block(model, "Window", at, Vector3.new(5, 6.4, 0.8), WINDOW, {
				material = Enum.Material.Glass,
				reflectance = 0.12,
				collide = false,
			})
			Builder.block(model, "WindowFrame", at * CFrame.new(0, 0, -0.3), Vector3.new(6.8, 8.2, 0.6), RED, {
				material = Enum.Material.Wood,
				collide = false,
			})
		end
	end

	-- ---- stacked cone roofs --------------------------------------------------
	-- Three diminishing cones, each sitting on its own overhanging eave disc.
	local coneY = drumTop
	local coneDiameter = drumDiameter + 16
	for i = 1, tiers do
		Builder.cylinder(
			model,
			`ConeEave{i}`,
			base * CFrame.new(0, coneY, drumZ),
			coneDiameter + 8,
			3,
			spec.roofColor,
			{ material = Enum.Material.Slate, castShadow = i == 1 }
		)

		local coneHeight = 22 - i * 2
		Builder.coneRoof(
			model,
			base * CFrame.new(0, coneY + 1.5, drumZ),
			coneDiameter,
			coneHeight,
			spec.roofColor,
			5
		)

		coneY += coneHeight
		coneDiameter *= 0.74
	end

	-- Gold finial.
	Builder.tube(model, "Finial", base * CFrame.new(0, coneY + 7, drumZ), 2.4, 15, GOLD, {
		material = Enum.Material.Metal,
	})
	Builder.sphere(
		model,
		"FinialBall",
		(base * CFrame.new(0, coneY + 16, drumZ)).Position,
		5,
		GOLD,
		{ material = Enum.Material.Metal }
	)

	-- ---- entrance ------------------------------------------------------------
	local faceZ = drumZ + drumDiameter / 2

	-- Flat red facade across the drum's curve, so the doors sit on something
	-- square. A door panel bent round a cylinder reads as a mistake.
	Builder.block(
		model,
		"EntranceFacade",
		base * CFrame.new(0, platformH + 12, faceZ + 0.4),
		Vector3.new(46, 24, 2),
		RED,
		{ material = Enum.Material.Plaster }
	)

	local doors = Builder.block(
		model,
		"Doors",
		base * CFrame.new(0, platformH + 10.5, faceZ + 1.8),
		Vector3.new(22, 21, 1.4),
		RED_DEEP,
		{ material = Enum.Material.WoodPlanks }
	)
	-- Centre split and frame, so it reads as a double door and not a red rectangle.
	Builder.block(model, "DoorSplit", base * CFrame.new(0, platformH + 10.5, faceZ + 2.6), Vector3.new(0.8, 21, 0.6), TRIM, {
		material = Enum.Material.Wood,
		collide = false,
	})
	Builder.block(model, "DoorLintel", base * CFrame.new(0, platformH + 22, faceZ + 2.2), Vector3.new(26, 2.4, 1.4), TRIM, {
		material = Enum.Material.Wood,
		collide = false,
	})

	-- Small square windows flanking the doors, red-framed as in the reference.
	for _, sx in { -1, 1 } do
		for i = 0, 1 do
			local at = base * CFrame.new(sx * (14 + i * 7), platformH + 15, faceZ + 1.8)
			Builder.block(model, "Window", at, Vector3.new(4, 5, 0.6), WINDOW, {
				material = Enum.Material.Glass,
				collide = false,
			})
		end
	end

	-- Steps down to the forecourt.
	for i = 0, 2 do
		Builder.block(
			model,
			"Step",
			base * CFrame.new(0, platformH - 1 - i * 1.3, faceZ + 4 + i * 3),
			Vector3.new(52, 1.4, 3.2 + i * 0.4),
			spec.trimColor,
			{ material = Enum.Material.Slate }
		)
	end

	-- ---- back door -----------------------------------------------------------
	-- Opens onto the courtyard. Without it the yard reads as a fenced-off lot
	-- that happens to be next to a school rather than part of it.
	-- The rear mass sits at -depth/2 + 22 and tieredRoof insets its wall band to
	-- 92% of the 46-stud depth, so its back face lands 21 studs behind that.
	local backZ = -spec.depth / 2 + 22 - 21
	Builder.block(
		model,
		"BackDoors",
		base * CFrame.new(0, platformH + 10, backZ - 0.8),
		Vector3.new(24, 20, 1.4),
		RED_DEEP,
		{ material = Enum.Material.WoodPlanks }
	)
	Builder.block(
		model,
		"BackDoorFrame",
		base * CFrame.new(0, platformH + 10.5, backZ - 0.2),
		Vector3.new(29, 23, 1),
		TRIM,
		{ material = Enum.Material.Wood, collide = false }
	)
	-- Small tiled porch roof over it.
	Builder.block(
		model,
		"BackPorch",
		base * CFrame.new(0, platformH + 24, backZ - 3),
		Vector3.new(38, 1.6, 8),
		spec.roofColor,
		{ material = Enum.Material.Slate, collide = false }
	)
	for i = 0, 2 do
		Builder.block(
			model,
			"BackStep",
			base * CFrame.new(0, platformH - 1 - i * 1.3, backZ - 4 - i * 3),
			Vector3.new(30, 1.4, 3.2),
			spec.trimColor,
			{ material = Enum.Material.Slate }
		)
	end

	-- ---- the crest -----------------------------------------------------------
	-- Hung from the first skirt on two straps. Details.crest wants a plain frame
	-- and applies its own facing rotation.
	local crestY = platformH + 36
	for _, sx in { -1, 1 } do
		Builder.tube(
			model,
			"CrestStrap",
			base * CFrame.new(sx * 9, crestY + 12, faceZ + 1.6),
			1,
			16,
			GREY,
			{ material = Enum.Material.Metal }
		)
	end

	Details.crest(model, base * CFrame.new(0, crestY, faceZ + 2), 30, GREY)

	-- The white name banner across the top of the crest.
	local banner = Builder.block(
		model,
		"AcademyBanner",
		base * CFrame.new(0, crestY + 10, faceZ + 3),
		Vector3.new(48, 9, 0.8),
		TRIM,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	Builder.surfaceText(banner, Enum.NormalId.Front, "忍者アカデミー", RED_DEEP, 0.82)

	Builder.anchorModel(model, platform)
	return model
end

-- ============================================================ Hokage Tower

-- Built to the reference: a broad red drum, cream band with the circular 火 crest,
-- a wide golden tiled skirt roof, and a blue-grey conical cap with spikes.
function Structures.hokageTower(parent: Instance, position: Vector3): Model
	local model = Builder.group("HokageTower", parent)
	local base = CFrame.new(Vector3.new(position.X, 0, position.Z))

	local RED = Color3.fromRGB(178, 64, 50)
	local CREAM = Color3.fromRGB(238, 228, 206)
	local GOLD = Color3.fromRGB(214, 168, 74)
	local BLUE = Color3.fromRGB(104, 122, 146)

	local drumDiameter = 150
	local drumHeight = 78

	-- Wide golden skirt roof at the base, overhanging a colonnade.
	Builder.cylinder(model, "SkirtRoof", base * CFrame.new(0, 26, 0), drumDiameter + 74, 4, GOLD, {
		material = Enum.Material.Slate,
		castShadow = true,
	})
	Builder.cylinder(model, "SkirtLip", base * CFrame.new(0, 23, 0), drumDiameter + 58, 3, GOLD, {
		material = Enum.Material.Slate,
	})

	-- Ground floor with the wooden double doors.
	local ground = Builder.cylinder(model, "Ground", base * CFrame.new(0, 13, 0), drumDiameter + 22, 26, CREAM, {
		material = Enum.Material.Plaster,
	})
	Builder.block(
		model,
		"MainDoors",
		base * CFrame.new(0, 11, (drumDiameter + 22) / 2),
		Vector3.new(34, 22, 1.6),
		Color3.fromRGB(186, 146, 78),
		{ material = Enum.Material.WoodPlanks }
	)

	-- The red drum.
	Builder.cylinder(model, "Drum", base * CFrame.new(0, 28 + drumHeight / 2, 0), drumDiameter, drumHeight, RED, {
		material = Enum.Material.Plaster,
		castShadow = true,
	})

	-- Small square windows in two rings.
	for ring = 0, 1 do
		for i = 0, 17 do
			local theta = (i / 18) * math.pi * 2
			Builder.block(
				model,
				"Window",
				base
					* CFrame.Angles(0, theta, 0)
					* CFrame.new(0, 44 + ring * 22, drumDiameter / 2),
				Vector3.new(6, 6, 0.8),
				Color3.fromRGB(72, 66, 62),
				{ material = Enum.Material.Glass, collide = false }
			)
		end
	end

	-- Cream band near the top, carrying the crest.
	Builder.cylinder(model, "Band", base * CFrame.new(0, 92, 0), drumDiameter + 5, 20, CREAM, {
		material = Enum.Material.Plaster,
	})

	-- The 火 crest: red ring on a cream disc, on the south and north faces.
	--
	-- The ring is rotated -90° about X because Builder.cylinder stands its axis
	-- along the frame's UP vector; without this the disc would sit flat like a coin
	-- on a table instead of facing out from the drum.
	for _, sz in { 1, -1 } do
		local at = base * CFrame.new(0, 92, sz * (drumDiameter / 2 + 3.5))
		Builder.cylinder(
			model,
			"CrestRing",
			at * CFrame.Angles(math.rad(-90), 0, 0),
			34,
			2,
			RED,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
		local disc = Builder.block(
			model,
			"CrestFace",
			at * CFrame.new(0, 0, sz * 1.6),
			Vector3.new(24, 24, 0.8),
			CREAM,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
		Builder.surfaceText(
			disc,
			if sz > 0 then Enum.NormalId.Front else Enum.NormalId.Back,
			"火",
			RED,
			0.95
		)
	end

	-- Observation balcony ring with railing.
	Builder.cylinder(model, "Balcony", base * CFrame.new(0, 104, 0), drumDiameter + 40, 3, CREAM, {
		material = Enum.Material.Concrete,
	})
	for i = 0, 23 do
		local theta = (i / 24) * math.pi * 2
		Builder.tube(
			model,
			"Baluster",
			base * CFrame.Angles(0, theta, 0) * CFrame.new(0, 109, (drumDiameter + 38) / 2),
			1,
			9,
			CREAM,
			{ material = Enum.Material.Concrete }
		)
	end

	-- Blue-grey conical cap.
	Builder.coneRoof(model, base * CFrame.new(0, 106, 0), drumDiameter + 16, 62, BLUE, 7)

	-- The spikes radiating off the cap — unmistakable in the reference.
	for i = 0, 3 do
		local theta = (i / 4) * math.pi * 2 + math.pi / 4
		Builder.block(
			model,
			"CapSpike",
			base
				* CFrame.Angles(0, theta, 0)
				* CFrame.new(0, 132, 38)
				* CFrame.Angles(math.rad(-58), 0, 0),
			Vector3.new(4, 46, 4),
			CREAM,
			{ material = Enum.Material.Concrete, collide = false }
		)
	end

	-- Central mast.
	Builder.tube(model, "Mast", base * CFrame.new(0, 186, 0), 3, 44, CREAM, {
		material = Enum.Material.Concrete,
	})

	Builder.anchorModel(model, ground)
	return model
end

-- ============================================================ main gate

-- The canon gate: two tall pillars with rounded caps, a cream lintel board
-- reading 忍 ⃝ 忍 in red, and green plank doors swung open.
function Structures.mainGate(parent: Instance, at: CFrame, openingWidth: number): Model
	local model = Builder.group("MainGate", parent)

	local STONE = Color3.fromRGB(206, 200, 186)
	local GREEN = Color3.fromRGB(118, 158, 126)
	local RED = Color3.fromRGB(184, 56, 44)
	local CREAM = Color3.fromRGB(242, 238, 224)

	local pillarHeight = 108
	local pillarWidth = 22
	local half = openingWidth / 2

	local anchor: BasePart? = nil

	for _, sx in { -1, 1 } do
		local pillar = Builder.block(
			model,
			"Pillar",
			at * CFrame.new(sx * (half + pillarWidth / 2), pillarHeight / 2, 0),
			Vector3.new(pillarWidth, pillarHeight, 26),
			STONE,
			{ material = Enum.Material.Concrete, castShadow = true }
		)
		anchor = anchor or pillar

		-- Rounded cap, like a rolled scroll end.
		Builder.cylinder(
			model,
			"PillarCap",
			at * CFrame.new(sx * (half + pillarWidth / 2), pillarHeight, 0) * CFrame.Angles(0, 0, math.rad(90)),
			pillarWidth,
			26,
			STONE,
			{ material = Enum.Material.Concrete }
		)
	end

	-- Lintel board across the top.
	local board = Builder.block(
		model,
		"LintelBoard",
		at * CFrame.new(0, pillarHeight - 14, 0),
		Vector3.new(openingWidth + 8, 30, 4),
		CREAM,
		{ material = Enum.Material.SmoothPlastic, castShadow = true }
	)
	-- Border frame.
	for _, sy in { -1, 1 } do
		Builder.block(
			model,
			"LintelEdge",
			at * CFrame.new(0, pillarHeight - 14 + sy * 15, 0),
			Vector3.new(openingWidth + 10, 3, 5),
			Color3.fromRGB(150, 158, 150),
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end

	-- 忍 ⃝ 忍 — the leaf spiral in the middle, shinobi either side.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Builder.surfaceText(board, face, "忍  ◎  忍", RED, 0.62)
	end

	-- The two doors, swung inward and open.
	for _, sx in { -1, 1 } do
		local door = Builder.block(
			model,
			"Door",
			at
				* CFrame.new(sx * (half - 2), 40, -16)
				* CFrame.Angles(0, math.rad(sx * 68), 0),
			Vector3.new(openingWidth * 0.52, 76, 3.4),
			GREEN,
			{ material = Enum.Material.WoodPlanks, castShadow = true }
		)
		-- Big red kanji painted across each door.
		Builder.surfaceText(door, Enum.NormalId.Front, if sx < 0 then "木" else "葉", RED, 0.72)

		-- Plank battens.
		for i = -1, 1 do
			Builder.block(
				model,
				"Batten",
				door.CFrame * CFrame.new(0, i * 24, 2),
				Vector3.new(openingWidth * 0.52, 3, 1),
				Color3.fromRGB(96, 132, 104),
				{ material = Enum.Material.Wood, collide = false }
			)
		end
	end

	-- Guard booth just inside.
	Builder.block(
		model,
		"GuardBooth",
		at * CFrame.new(half + 40, 12, -44),
		Vector3.new(26, 24, 22),
		CREAM,
		{ material = Enum.Material.Plaster }
	)
	Builder.block(
		model,
		"BoothRoof",
		at * CFrame.new(half + 40, 25, -44),
		Vector3.new(32, 2, 28),
		Color3.fromRGB(148, 88, 68),
		{ material = Enum.Material.Slate }
	)

	if anchor then
		Builder.anchorModel(model, anchor)
	end
	return model
end

-- ============================================================ spire

-- The tall thin tower with the steep blue cone, visible on every skyline shot.
function Structures.spire(parent: Instance, position: Vector3, height: number): Model
	local model = Builder.group("SpireTower", parent)
	local base = CFrame.new(Vector3.new(position.X, 0, position.Z))

	local WALL = Color3.fromRGB(228, 220, 200)
	local BLUE = Color3.fromRGB(72, 104, 156)
	local TRIM = Color3.fromRGB(188, 76, 62)

	local body = Builder.cylinder(model, "Body", base * CFrame.new(0, height / 2, 0), 46, height, WALL, {
		material = Enum.Material.Plaster,
		castShadow = true,
	})

	for i = 1, 4 do
		Builder.cylinder(model, "Band", base * CFrame.new(0, height * (i / 5), 0), 49, 2, TRIM, {
			material = Enum.Material.Concrete,
		})
		for j = 0, 7 do
			local theta = (j / 8) * math.pi * 2
			Builder.block(
				model,
				"Window",
				base * CFrame.Angles(0, theta, 0) * CFrame.new(0, height * (i / 5) + 7, 23),
				Vector3.new(4.4, 7, 0.7),
				Color3.fromRGB(150, 190, 220),
				{ material = Enum.Material.Glass, collide = false }
			)
		end
	end

	Builder.cylinder(model, "Eave", base * CFrame.new(0, height + 1, 0), 62, 3, BLUE, {
		material = Enum.Material.Slate,
	})
	-- Steep cone — more steps than usual so it reads tall and sharp.
	Builder.coneRoof(model, base * CFrame.new(0, height + 2, 0), 58, 74, BLUE, 9)
	Builder.sphere(
		model,
		"Finial",
		(base * CFrame.new(0, height + 80, 0)).Position,
		6,
		Color3.fromRGB(224, 190, 108),
		{ material = Enum.Material.Metal }
	)

	Builder.anchorModel(model, body)
	return model
end

return Structures
